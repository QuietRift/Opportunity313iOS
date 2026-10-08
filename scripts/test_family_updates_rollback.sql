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

alter table ticket_fixture add column update_id uuid default gen_random_uuid();
update public.opportunities set capacity=2 where id=(select opportunity_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
do $$
declare f record; result jsonb;
begin
 select * into f from ticket_fixture;
 begin
  perform public.native_register_family(f.opportunity_id,array[f.child_id,f.sibling_id],true);
  raise exception 'FAILED: over-capacity family succeeded';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='This opportunity is full','Capacity rejection');
 end;
 perform pg_temp.assert_true((select count(*)=0 from public.opportunity_tickets where opportunity_id=f.opportunity_id),'No partial registrations');
 result:=public.native_register_family(f.opportunity_id,array[f.child_id,f.sibling_id,f.child_id],false);
 perform pg_temp.assert_true(jsonb_array_length(result)=2,'Deduplicated family selection');
 result:=public.native_register_family(f.opportunity_id,array[f.child_id,f.sibling_id],false);
 perform pg_temp.assert_true(jsonb_array_length(result)=2,'Family retry returns existing registrations');
 begin
  perform public.native_publish_opportunity_update(f.opportunity_id,'Reminder','Bring a water bottle',f.update_id);
  raise exception 'FAILED: parent sent provider update';
 exception when raise_exception then
  if sqlerrm like 'FAILED:%' then raise; end if;
  perform pg_temp.assert_true(sqlerrm='Organization access required','Parent cannot send provider updates');
 end;
end $$;
select set_config('request.jwt.claim.sub',(select provider_id::text from ticket_fixture),true);
do $$
declare f record; recipients integer;
begin
 select * into f from ticket_fixture;
 recipients:=public.native_publish_opportunity_update(f.opportunity_id,'Reminder','Bring a water bottle',f.update_id);
 perform pg_temp.assert_true(recipients=3,'Two children and one deduplicated parent notified');
 recipients:=public.native_publish_opportunity_update(f.opportunity_id,'Reminder','Bring a water bottle',f.update_id);
 perform pg_temp.assert_true(recipients=3,'Update retry idempotent');
 perform pg_temp.assert_true((select count(*)=0 from public.registration_notifications),'Provider cannot read recipient inboxes');
end $$;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
select pg_temp.assert_true((select count(*)=1 from public.registration_notifications),'Parent sees one update');
select public.native_read_registration_update(id) from public.registration_notifications;
select pg_temp.assert_true((select bool_and(read_at is not null) from public.registration_notifications),'Read receipt');
select set_config('request.jwt.claim.sub',(select child_user::text from ticket_fixture),true);
select pg_temp.assert_true((select count(*)=1 from public.registration_notifications),'Child receives own update');
reset role;
delete from public.guardian_relationships where youth_profile_id in (select child_id from ticket_fixture union select sibling_id from ticket_fixture) and guardian_user_id=(select parent_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from ticket_fixture),true);
select pg_temp.assert_true((select count(*)=0 from public.registration_notifications),'Revoked guardian cannot read child updates');
reset role;
select pg_temp.assert_true((select count(*)=3 from public.registration_notifications where update_id=(select update_id from ticket_fixture)),'No duplicate notifications');
select pg_temp.assert_true((select count(*)=0 from public.registration_push_queue q join public.registration_notifications n on n.id=q.notification_id where n.update_id=(select update_id from ticket_fixture)),'Demo sends no phone alerts');
-- Targeted push delivery uses account-bound devices and bounded leases.
update public.opportunities set is_demo=false where id=(select opportunity_id from ticket_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select sibling_user::text from ticket_fixture),true);
select public.native_registration_push_device('fixture-registration-device-token',true);
select set_config('request.jwt.claim.sub',(select provider_id::text from ticket_fixture),true);
select pg_temp.assert_true(public.native_publish_opportunity_update((select opportunity_id from ticket_fixture),'Second reminder','Use the main entrance',gen_random_uuid())=2,'Revoked parent is excluded from future updates');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.registration_push_queue),'Only registered device gets a push');
grant select on ticket_fixture to service_role;
set local role service_role;
create temporary table push_claim as select * from public.claim_registration_push_events();
select pg_temp.assert_true((select count(*)=1 from push_claim),'Service worker claims target');
select pg_temp.assert_true((select count(*)=0 from public.claim_registration_push_events()),'Active lease cannot be claimed twice');
select public.finish_registration_push_event(id,lease_id,true,false) from push_claim;
select pg_temp.assert_true((select bool_and(finished) from public.registration_push_queue),'Successful delivery finishes queue');
reset role;
select 'PASS: atomic family registration, recipient privacy, targeted device dispatch, exclusive lease and completion' result;
rollback;
