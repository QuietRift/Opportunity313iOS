begin;
create temporary table school_eligibility_test as
select gr.guardian_user_id parent_id, gr.youth_profile_id youth_id,
       (select user_id from public.user_roles where role='admin' limit 1) admin_id,
       e.id event_id,e.school_id,s.organization_id,a.id allocation_id,
       null::uuid staff_id,null::uuid verification_id,null::uuid hold_id,null::uuid ticket_id,null::text token
from public.guardian_relationships gr
cross join public.ticket_allocations a
join public.events e on e.id=a.event_id
join public.schools s on s.id=e.school_id
where gr.status='active' and a.eligibility_kind='student' and e.is_demo
order by (select count(*) from public.tickets t where t.allocation_id=a.id and t.claimed_by=gr.guardian_user_id and t.status in ('issued','scanned')) asc
limit 1;
grant select,update on school_eligibility_test to authenticated;
with new_staff as (
 insert into auth.users(id,email,email_confirmed_at)
 values(extensions.gen_random_uuid(),'school-ticket-test-'||extensions.gen_random_uuid()||'@example.invalid',now())
 returning id
)
update school_eligibility_test c set staff_id=new_staff.id from new_staff;
insert into public.user_roles(user_id,role,assigned_by)
select staff_id,'athletics',admin_id from school_eligibility_test;
insert into public.athletics_memberships(user_id,organization_id,school_id,role,status)
select staff_id,organization_id,school_id,'school_admin','active' from school_eligibility_test;
update public.events set starts_at=now()+interval '1 day',sales_open_at=now()-interval '1 day',
 sales_close_at=now()+interval '12 hours',event_status='on_sale'
where id=(select event_id from school_eligibility_test);
set local role authenticated;
do $$
declare c record; h public.ticket_holds%rowtype; issued record; other_allocation uuid; request_id uuid;
begin
 select * into c from school_eligibility_test;
 if c.parent_id is null or c.youth_id is null or c.staff_id is null then raise exception 'Missing fixture'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 perform public.native_request_school_verification(c.youth_id,c.school_id);
 begin
  perform public.native_create_ticket_hold(c.allocation_id,1,'school-pending-test-'||extensions.gen_random_uuid(),c.youth_id);
  raise exception 'Pending school bypassed';
 exception when raise_exception then
  if sqlerrm<>'This student is not verified for the event school' then raise; end if;
 end;
 perform set_config('request.jwt.claims',json_build_object('sub',c.staff_id,'role','authenticated')::text,true);
 if exists(select 1 from jsonb_array_elements(public.native_school_verification_queue()) x
  where x->>'youth_profile_id'=c.youth_id::text) then raise exception 'Request appeared before ID photo step'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 perform public.native_submit_school_roster_request(c.youth_id,c.school_id);
 perform set_config('request.jwt.claims',json_build_object('sub',c.staff_id,'role','authenticated')::text,true);
 select (x->>'id')::uuid into request_id from jsonb_array_elements(public.native_school_verification_queue()) x
 where x->>'youth_profile_id'=c.youth_id::text limit 1;
 if request_id is null then raise exception 'School queue missing request'; end if;
 update school_eligibility_test set verification_id=request_id;
 perform set_config('request.jwt.claims',json_build_object('sub',c.admin_id,'role','authenticated')::text,true);
 begin
  perform public.native_review_school_roster(request_id,true,true);
  raise exception 'Platform admin bypassed school verification';
 exception when raise_exception then
  if sqlerrm<>'School verification request unavailable' then raise; end if;
 end;
 perform set_config('request.jwt.claims',json_build_object('sub',c.staff_id,'role','authenticated')::text,true);
 begin
  perform public.native_review_school_roster(request_id,true,false);
  raise exception 'Roster check bypassed';
 exception when raise_exception then
  if sqlerrm<>'Check the school roster before approval' then raise; end if;
 end;
 perform public.native_review_school_roster(request_id,true,true);
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 select a.id into other_allocation from public.ticket_allocations a join public.events e on e.id=a.event_id
 where a.eligibility_kind='student' and e.school_id<>c.school_id limit 1;
 if other_allocation is null then raise exception 'Wrong-school fixture missing'; end if;
 begin
  perform public.native_create_ticket_hold(other_allocation,1,'school-wrong-test-'||extensions.gen_random_uuid(),c.youth_id);
  raise exception 'Wrong-school student ticket allowed';
 exception when raise_exception then
  if sqlerrm<>'This student is not verified for the event school' then raise; end if;
 end;
 h := public.native_create_ticket_hold(c.allocation_id,1,'school-verified-test-'||extensions.gen_random_uuid(),c.youth_id);
 if h.assigned_youth_profile_id<>c.youth_id or abs(extract(epoch from (h.expires_at-now()))-300)>10 then
  raise exception 'Student hold missing identity or five-minute expiry';
 end if;
 select * into issued from public.issue_ticket(h.id);
 if issued.ticket_id is null or length(issued.token)<>64 then raise exception 'Student ticket not issued'; end if;
 if (select count(*) from public.issue_ticket(h.id))<>0 then raise exception 'Retry issued another student ticket'; end if;
 update school_eligibility_test set hold_id=h.id,ticket_id=issued.ticket_id,token=issued.token;
 begin
  perform public.native_create_ticket_hold(c.allocation_id,1,'school-duplicate-test-'||extensions.gen_random_uuid(),c.youth_id);
  raise exception 'Duplicate student ticket allowed';
 exception when raise_exception then
  if sqlerrm<>'This student already has a ticket or active hold for this event' then raise; end if;
 end;
end $$;
reset role;
update public.youth_profiles set first_name=first_name||' Test' where id=(select youth_id from school_eligibility_test);
set local role authenticated;
do $$
declare c record; scanned text;
begin
 select * into c from school_eligibility_test;
 perform set_config('request.jwt.claims',json_build_object('sub',c.staff_id,'role','authenticated')::text,true);
 begin
  perform * from public.native_staff_check_in(c.token,c.event_id,false);
  raise exception 'Changed student identity admitted';
 exception when raise_exception then
  if sqlerrm<>'Student school verification is unavailable; do not admit on this ticket' then raise; end if;
 end;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 perform public.native_submit_school_roster_request(c.youth_id,c.school_id);
 perform set_config('request.jwt.claims',json_build_object('sub',c.staff_id,'role','authenticated')::text,true);
 perform public.native_review_school_roster(c.verification_id,true,true);
 select result::text into scanned from public.native_staff_check_in(c.token,c.event_id,false);
 if scanned<>'accepted' then raise exception 'Verified student was not admitted'; end if;
end $$;
rollback;
select 'PASS: photo submission queue, roster approval, pending/wrong-school denial, assigned student ticket, identity-change reset, check-in; all changes rolled back' result;
