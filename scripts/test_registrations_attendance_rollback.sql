-- Run the complete file as one transaction. All fixtures and writes roll back.
begin;
create temporary table ticket_fixture as
select gr.guardian_user_id parent_id, yp.id child_id, yp.user_id child_user,
 (select yp2.id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_id,
 (select yp2.user_id from public.guardian_relationships gr2 join public.youth_profiles yp2 on yp2.id=gr2.youth_profile_id where gr2.guardian_user_id=gr.guardian_user_id and gr2.status='active' and yp2.id<>yp.id and yp2.user_id is not null limit 1) sibling_user,
 gen_random_uuid() opportunity_id, gen_random_uuid() external_id
from public.guardian_relationships gr join public.youth_profiles yp on yp.id=gr.youth_profile_id
where gr.status='active' and yp.user_id is not null limit 1;
grant select, update on ticket_fixture to authenticated;
create function pg_temp.assert_true(value boolean, message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAILED: %', message; end if; end $$;
select pg_temp.assert_true((select child_user is not null and sibling_user is not null from ticket_fixture),'Two linked signed-in child fixtures required');
alter table ticket_fixture add column child_registration uuid, add column provider_id uuid, add column provider_org uuid, add column foreign_org uuid default gen_random_uuid(), add column independent_profile uuid, add column independent_user uuid;
update ticket_fixture set
 provider_id=(select om.user_id from public.org_members om join public.user_roles ur on ur.user_id=om.user_id where om.status='active' and ur.role='provider' limit 1),
 provider_org=(select om.organization_id from public.org_members om join public.user_roles ur on ur.user_id=om.user_id where om.status='active' and ur.role='provider' limit 1),
 independent_profile=(select id from public.youth_profiles where account_type='youth_account' and user_id is not null limit 1),
 independent_user=(select user_id from public.youth_profiles where account_type='youth_account' and user_id is not null limit 1);
select pg_temp.assert_true((select provider_id is not null and independent_user is not null from ticket_fixture),'Provider and independent youth fixtures required');
insert into public.organizations select (jsonb_populate_record(null::public.organizations,to_jsonb(o)||jsonb_build_object('id',f.foreign_org,'name','Registration rollback foreign organization'))).* from public.organizations o cross join ticket_fixture f where o.id=f.provider_org;
insert into public.opportunities
select (jsonb_populate_record(null::public.opportunities, to_jsonb(o) || jsonb_build_object(
 'id',f.opportunity_id,'organization_id',f.provider_org,'title','Dashboard ticket rollback fixture','registration_method','in_app','registration_url',null,
 'age_min',null,'age_max',null,'grade_min',null,'grade_max',null,'gender_eligibility','all',
 'is_free',true,'cost_cents',0,'is_demo',true,'capacity',3,
 'starts_at',now()+interval '30 days','ends_at',now()+interval '30 days 2 hours','deadline',now()+interval '29 days'
))).* from public.opportunities o cross join ticket_fixture f where o.status='published' limit 1;
insert into public.opportunities
select (jsonb_populate_record(null::public.opportunities,to_jsonb(o)||jsonb_build_object('id',f.external_id,'organization_id',f.foreign_org,'capacity',null))).* from public.opportunities o cross join ticket_fixture f where o.id=f.opportunity_id;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
select public.native_register_opportunity(opportunity_id,null)->>'status' from ticket_fixture;
select public.native_register_opportunity(opportunity_id,child_id)->>'status' from ticket_fixture;
select public.native_register_opportunity(opportunity_id,sibling_id)->>'status' from ticket_fixture;
do $$
declare f record; wallet jsonb;
begin
 select * into f from ticket_fixture;
 wallet:=public.native_my_registrations();
 perform pg_temp.assert_true((select count(*)=3 from jsonb_array_elements(wallet) t where t->>'opportunity_id'=f.opportunity_id::text),'Parent sees family registrations');
 perform pg_temp.assert_true((select bool_and((t->>'can_cancel')::boolean) from jsonb_array_elements(wallet) t where t->>'opportunity_id'=f.opportunity_id::text),'Parent can cancel family registrations');
end $$;
select set_config('request.jwt.claim.sub',(select child_user::text from ticket_fixture),true);
do $$
declare f record; wallet jsonb; child_registration uuid;
begin
 select * into f from ticket_fixture;
 wallet:=public.native_my_registrations();
 perform pg_temp.assert_true((select count(*)=1 from jsonb_array_elements(wallet) t where t->>'opportunity_id'=f.opportunity_id::text),'Child sees only own registration');
 select (t->>'id')::uuid into child_registration from jsonb_array_elements(wallet) t where t->>'opportunity_id'=f.opportunity_id::text;
 perform pg_temp.assert_true((select not (t->>'can_cancel')::boolean from jsonb_array_elements(wallet) t where t->>'id'=child_registration::text),'Managed child is view-only');
 begin
  perform public.native_cancel_opportunity_registration(child_registration);
  raise exception 'FAILED: Managed child cancelled registration';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='You cannot cancel this registration','Child cancellation denied');
 end;
 begin
  perform public.native_opportunity_attendees(f.opportunity_id);
  raise exception 'FAILED: Child read provider roster';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Organization access required','Child roster access denied');
 end;
end $$;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
do $$
declare f record; registration uuid; first_result jsonb; retry jsonb;
begin
 select * into f from ticket_fixture;
 select id into registration from public.opportunity_tickets where opportunity_id=f.opportunity_id and youth_profile_id=f.child_id;
 first_result:=public.native_cancel_opportunity_registration(registration);
 retry:=public.native_cancel_opportunity_registration(registration);
 perform pg_temp.assert_true(first_result->>'status'='cancelled','Parent cancellation succeeds');
 perform pg_temp.assert_true(first_result->>'cancelled_at'=retry->>'cancelled_at','Cancellation retry is idempotent');
end $$;
select set_config('request.jwt.claim.sub',(select provider_id::text from ticket_fixture),true);
do $$
declare f record; roster jsonb; registration uuid;
begin
 select * into f from ticket_fixture;
 roster:=public.native_opportunity_attendees(f.opportunity_id);
 perform pg_temp.assert_true((roster->>'registered_count')::int=2 and (roster->>'remaining')::int=1,'Cancellation releases a spot in roster');
 perform pg_temp.assert_true((roster->>'cancelled_count')::int=1,'Roster retains cancellation history');
 perform pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(roster->'attendees') t where t ? 'entry_code' or t ? 'attendee_user_id' or t ? 'youth_profile_id'),'Roster does not expose codes or user IDs');
 perform pg_temp.assert_true((select count(*)=0 from public.opportunity_tickets where opportunity_id=f.opportunity_id),'Provider cannot directly read family ticket codes');
 select (t->>'id')::uuid into registration from jsonb_array_elements(roster->'attendees') t where t->>'status'='cancelled';
 begin
  perform public.native_mark_opportunity_attendance(registration);
  raise exception 'FAILED: Provider attended cancelled registration';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Only a confirmed registration can be marked attended','Cancelled attendance denied');
 end;
 begin
  perform public.native_opportunity_attendees(f.external_id);
  raise exception 'FAILED: Provider accessed another organization';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Organization access required','Cross-organization roster denied');
 end;
end $$;
select set_config('request.jwt.claim.sub',(select child_user::text from ticket_fixture),true);
do $$
declare f record; ticket jsonb;
begin
 select * into f from ticket_fixture;
 ticket:=public.native_register_opportunity(f.opportunity_id,f.child_id);
 update ticket_fixture set child_registration=(ticket->>'id')::uuid;
end $$;
select set_config('request.jwt.claim.sub',(select provider_id::text from ticket_fixture),true);
do $$
declare f record; roster jsonb; registration uuid; first_attended text;
begin
 select * into f from ticket_fixture;
 roster:=public.native_opportunity_attendees(f.opportunity_id);
 perform pg_temp.assert_true((roster->>'registered_count')::int=3 and (roster->>'remaining')::int=0,'Re-registration consumes released spot');
 registration:=f.child_registration;
 perform public.native_mark_opportunity_attendance(registration);
 roster:=public.native_opportunity_attendees(f.opportunity_id);
 select t->>'attended_at' into first_attended from jsonb_array_elements(roster->'attendees') t where t->>'id'=registration::text;
 perform public.native_mark_opportunity_attendance(registration);
 roster:=public.native_opportunity_attendees(f.opportunity_id);
 perform pg_temp.assert_true((roster->>'attended_count')::int=1,'Attendance recorded once');
 perform pg_temp.assert_true((select t->>'attended_at'=first_attended from jsonb_array_elements(roster->'attendees') t where t->>'id'=registration::text),'Attendance retry preserves timestamp');
end $$;
select set_config('request.jwt.claim.sub',(select child_user::text from ticket_fixture),true);
do $$
declare f record; wallet jsonb;
begin
 select * into f from ticket_fixture;
 wallet:=public.native_my_registrations();
 perform pg_temp.assert_true((select t->>'status'='used' and not (t->>'can_cancel')::boolean from jsonb_array_elements(wallet) t where t->>'id'=f.child_registration::text),'Child sees own recorded attendance');
 begin
  perform public.native_mark_opportunity_attendance(f.child_registration);
  raise exception 'FAILED: Child marked own attendance';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Organization access required','Child cannot mark attendance');
 end;
end $$;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
do $$
declare registration uuid;
begin
 select id into registration from public.opportunity_tickets where opportunity_id=(select opportunity_id from ticket_fixture) and status='used';
 perform pg_temp.assert_true(registration is not null,'Attendance is visible to parent');
 begin
  perform public.native_cancel_opportunity_registration(registration);
  raise exception 'FAILED: Parent cancelled attended registration';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='An attended or expired registration cannot be cancelled','Attended cancellation denied');
 end;
end $$;
reset role;
-- Exercise an independent 18–24 account using a rolled-back transformation
-- of one fixture profile; existing child profiles remain unchanged afterward.
update ticket_fixture set independent_profile=child_id,independent_user=child_user;
update public.youth_profiles set age_band='18–24',account_type='youth_account' where id=(select independent_profile from ticket_fixture);
delete from public.guardian_relationships where youth_profile_id=(select independent_profile from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select independent_user::text from ticket_fixture),true);
do $$
declare f record; ticket jsonb;
begin
 select * into f from ticket_fixture;
 ticket:=public.native_register_opportunity(f.external_id,f.independent_profile);
 perform pg_temp.assert_true((select (t->>'can_cancel')::boolean from jsonb_array_elements(public.native_my_registrations()) t where t->>'id'=ticket->>'id'),'Independent youth can manage own registration');
 ticket:=public.native_cancel_opportunity_registration((ticket->>'id')::uuid);
 perform pg_temp.assert_true(ticket->>'status'='cancelled','Independent youth cancellation succeeds');
end $$;
reset role;
update public.opportunity_tickets set starts_at=now()-interval '1 hour' where opportunity_id=(select opportunity_id from ticket_fixture) and attendee_user_id=(select parent_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
do $$
declare registration uuid;
begin
 select id into registration from public.opportunity_tickets where opportunity_id=(select opportunity_id from ticket_fixture) and attendee_user_id=(select parent_id from ticket_fixture);
 begin
  perform public.native_cancel_opportunity_registration(registration);
  raise exception 'FAILED: Late cancellation succeeded';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Cancellation closes when the opportunity starts','Late cancellation denied');
 end;
end $$;
reset role;
delete from public.org_members where organization_id=(select provider_org from ticket_fixture) and user_id=(select provider_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select provider_id::text from ticket_fixture),true);
do $$
begin
 begin
  perform public.native_opportunity_attendees((select opportunity_id from ticket_fixture));
  raise exception 'FAILED: Revoked member read roster';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Organization access required','Revoked membership denied');
 end;
end $$;
reset role;
select 'PASS: family visibility, child view-only, parent and adult cancellation, freed capacity, re-registration, provider isolation, attendance, timestamps and membership revocation' as result;
rollback;
