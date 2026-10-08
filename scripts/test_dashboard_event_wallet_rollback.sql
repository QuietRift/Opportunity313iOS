begin;
create temporary table event_fixture as
select gr.guardian_user_id parent_id,yp.id child_id,yp.user_id child_user,
 (select yp2.id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_id,
 (select yp2.user_id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_user,
 (select id from public.ticket_allocations where eligibility_kind='general' limit 1) allocation_id,
 gen_random_uuid() adult_ticket,gen_random_uuid() child_ticket,gen_random_uuid() sibling_ticket
from public.guardian_relationships gr join public.youth_profiles yp on yp.id=gr.youth_profile_id where gr.status='active' and yp.user_id is not null limit 1;
grant select on event_fixture to authenticated;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAILED: %',message; end if; end $$;
update public.events set event_status='on_sale' where id=(select a.event_id from public.ticket_allocations a join event_fixture f on f.allocation_id=a.id);
insert into public.tickets(id,allocation_id,claimed_by,assigned_youth_profile_id,token_hash)
select f.adult_ticket,f.allocation_id,f.parent_id,null,encode(extensions.gen_random_bytes(32),'hex') from event_fixture f
union all
select f.child_ticket,f.allocation_id,f.parent_id,f.child_id,encode(extensions.gen_random_bytes(32),'hex') from event_fixture f
union all
select f.sibling_ticket,f.allocation_id,f.parent_id,f.sibling_id,encode(extensions.gen_random_bytes(32),'hex') from event_fixture f;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from event_fixture),true);
do $$
declare wallet jsonb; f record;
begin
 select * into f from event_fixture;
 wallet:=public.native_ticket_wallet();
 perform pg_temp.assert_true((select count(*)=3 from jsonb_array_elements(wallet) t where (t->>'id')::uuid in (f.adult_ticket,f.child_ticket,f.sibling_ticket)),'Parent event wallet sees family');
end $$;
select set_config('request.jwt.claim.sub',(select child_user::text from event_fixture),true);
do $$
declare wallet jsonb; f record; code text;
begin
 select * into f from event_fixture;
 wallet:=public.native_ticket_wallet();
 perform pg_temp.assert_true((select count(*)=1 from jsonb_array_elements(wallet) t where (t->>'id')::uuid in (f.adult_ticket,f.child_ticket,f.sibling_ticket)),'Child event wallet isolates assigned tickets');
 perform pg_temp.assert_true((select (t->>'can_manage_reservation')::boolean=false from jsonb_array_elements(wallet) t where (t->>'id')::uuid=f.child_ticket),'Child cannot cancel parent reservation');
 code:=public.native_replace_ticket_code(f.child_ticket);
 perform pg_temp.assert_true(length(code)=64,'Child can generate own event QR');
 begin
  perform public.native_replace_ticket_code(f.sibling_ticket);
  raise exception 'FAILED: Child generated sibling QR';
 exception when raise_exception then
  if sqlerrm='FAILED: Child generated sibling QR' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Ticket unavailable','Sibling QR denied');
 end;
 begin
  perform public.native_ticket_wallet((select event_id from public.ticket_allocations where id=f.allocation_id));
  raise exception 'FAILED: Child accessed staff wallet';
 exception when raise_exception then
  if sqlerrm='FAILED: Child accessed staff wallet' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Event staff access required','Staff wallet denied');
 end;
end $$;
reset role;
select 'PASS: existing event wallet family visibility, child isolation, QR access and staff access' as result;
rollback;
