-- Run the complete file as one transaction. All fixtures and writes roll back.
begin;
create temporary table ticket_fixture as
select gr.guardian_user_id parent_id, yp.id child_id, yp.user_id child_user,
 (select yp2.id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_id,
 (select yp2.user_id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_user,
 gen_random_uuid() opportunity_id, gen_random_uuid() external_id
from public.guardian_relationships gr join public.youth_profiles yp on yp.id=gr.youth_profile_id
where gr.status='active' and yp.user_id is not null limit 1;
grant select on ticket_fixture to authenticated;
create function pg_temp.assert_true(value boolean, message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAILED: %', message; end if; end $$;
select pg_temp.assert_true((select child_user is not null and sibling_user is not null from ticket_fixture),'Two linked signed-in child fixtures required');
insert into public.opportunities
select (jsonb_populate_record(null::public.opportunities, to_jsonb(o) || jsonb_build_object(
 'id',f.opportunity_id,'title','Dashboard ticket rollback fixture','registration_method','in_app','registration_url',null,
 'age_min',null,'age_max',null,'grade_min',null,'grade_max',null,'gender_eligibility','all',
 'is_free',true,'cost_cents',0,'is_demo',true,'capacity',3,
 'starts_at',now()+interval '30 days','ends_at',now()+interval '30 days 2 hours','deadline',now()+interval '29 days'
))).* from public.opportunities o cross join ticket_fixture f where o.status='published' limit 1;
insert into public.opportunities
select (jsonb_populate_record(null::public.opportunities,to_jsonb(o)||jsonb_build_object('id',f.external_id,'registration_method','external_url'))).* from public.opportunities o cross join ticket_fixture f where o.id=f.opportunity_id;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
do $$
declare f record; t jsonb; retry jsonb;
begin
 select * into f from ticket_fixture;
 t := public.native_register_opportunity(f.opportunity_id,null);
 perform pg_temp.assert_true(t->>'attendee_user_id'=f.parent_id::text,'Parent registers self');
 t := public.native_register_opportunity(f.opportunity_id,f.child_id);
 retry := public.native_register_opportunity(f.opportunity_id,f.child_id);
 perform pg_temp.assert_true(t->>'id'=retry->>'id','Retry returns same ticket');
 perform pg_temp.assert_true(length(t->>'entry_code')=64,'Ticket has QR payload');
 perform public.native_register_opportunity(f.opportunity_id,f.sibling_id);
 perform pg_temp.assert_true((select count(*)=3 from public.opportunity_tickets where opportunity_id=f.opportunity_id),'Parent sees all three family tickets');
 begin
  perform public.native_register_opportunity(f.external_id,null);
  raise exception 'FAILED: External registration issued a ticket';
 exception when raise_exception then
  if sqlerrm='FAILED: External registration issued a ticket' then raise; end if;
  perform pg_temp.assert_true(sqlerrm like 'Complete registration with the provider%', 'External link rejected');
 end;
 begin
  update public.opportunity_tickets set status='used' where opportunity_id=f.opportunity_id;
  raise exception 'FAILED: Client changed ticket status';
 exception when insufficient_privilege then null;
 end;
end $$;
select set_config('request.jwt.claim.sub',(select child_user::text from ticket_fixture),true);
do $$
declare f record;
begin
 select * into f from ticket_fixture;
 perform pg_temp.assert_true((select count(*)=1 from public.opportunity_tickets where opportunity_id=f.opportunity_id),'Child sees only their ticket');
 perform public.native_register_opportunity(f.opportunity_id,f.child_id);
 begin
  perform public.native_register_opportunity(f.opportunity_id,f.sibling_id);
  raise exception 'FAILED: Child registered sibling';
 exception when raise_exception then
  if sqlerrm='FAILED: Child registered sibling' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Attendee unavailable','Child cannot register sibling');
 end;
 begin
  perform public.native_register_opportunity(f.opportunity_id,null);
  raise exception 'FAILED: Child registered without profile';
 exception when raise_exception then
  if sqlerrm='FAILED: Child registered without profile' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Select your youth profile','Youth requires profile');
 end;
end $$;
select set_config('request.jwt.claim.sub',(select sibling_user::text from ticket_fixture),true);
select pg_temp.assert_true((select count(*)=1 from public.opportunity_tickets where opportunity_id=(select opportunity_id from ticket_fixture)),'Sibling sees only their ticket');
reset role;
-- Revocation must remove family access immediately, including old tickets.
update public.guardian_relationships set status='revoked' where guardian_user_id=(select parent_id from ticket_fixture) and youth_profile_id=(select child_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
select pg_temp.assert_true((select count(*)=2 from public.opportunity_tickets where opportunity_id=(select opportunity_id from ticket_fixture)),'Revoked relationship hides child ticket');
reset role;
-- Cancel fixtures to exercise closed/full/eligibility checks without retry shortcuts.
update public.opportunity_tickets set status='cancelled' where opportunity_id=(select opportunity_id from ticket_fixture);
update public.opportunities set capacity=1 where id=(select opportunity_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
select public.native_register_opportunity((select opportunity_id from ticket_fixture),null)->>'status' as issued_status;
do $$
begin
 begin
  perform public.native_register_opportunity((select opportunity_id from ticket_fixture),(select sibling_id from ticket_fixture));
  raise exception 'FAILED: Oversold capacity';
 exception when raise_exception then
  if sqlerrm='FAILED: Oversold capacity' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='This opportunity is full','Capacity enforced');
 end;
end $$;
reset role;
update public.opportunities set deadline=now()-interval '1 hour' where id=(select opportunity_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select sibling_user::text from ticket_fixture),true);
do $$
begin
 begin
  perform public.native_register_opportunity((select opportunity_id from ticket_fixture),(select sibling_id from ticket_fixture));
  raise exception 'FAILED: Closed registration succeeded';
 exception when raise_exception then
  if sqlerrm='FAILED: Closed registration succeeded' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Registration has closed','Deadline enforced');
 end;
end $$;
reset role;
select 'PASS: parent, child, sibling, retry, QR, external links, direct-write denial, revocation, capacity and deadline' as result;
rollback;
