begin;
create temp table push_test_context(key text primary key,id uuid);
insert into push_test_context select distinct on(role) role::text,user_id from public.user_roles where role in ('admin','provider') order by role,user_id;
insert into push_test_context values ('organization',gen_random_uuid()),('opportunity',gen_random_uuid()),('demo',gen_random_uuid()),('expired',gen_random_uuid());
insert into public.organizations(id,name,organization_type,verification_status)
select id,'Push rollback provider','nonprofit','verified' from push_test_context where key='organization';
insert into public.org_members(organization_id,user_id,role,status)
select (select id from push_test_context where key='organization'),id,'Provider manager','active' from push_test_context where key='provider';
grant select on push_test_context to authenticated,anon,service_role;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',(select id from push_test_context where key='provider'),'role','authenticated')::text,true);
insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,starts_at,cost_cents,is_free,location_name,registration_method,status,created_by,is_demo,deadline)
select id,(select id from push_test_context where key='organization'),'Push rollback opportunity','Review required','Technology','Workshop',now()+interval '7 days',0,true,'Detroit','provider_submission','pending_review',auth.uid(),key='demo',case when key='expired' then now()-interval '1 day' else null end
from push_test_context where key in ('opportunity','demo','expired');
do $$ begin
 begin
  update public.opportunities set status='published' where id=(select id from push_test_context where key='opportunity');
  raise exception 'Provider published directly';
 exception when insufficient_privilege then null; end;
 begin perform public.claim_opportunity_push_events(); raise exception 'Client claimed private queue'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.opportunity_push_events where opportunity_id in (select id from push_test_context)) then raise exception 'Pending submission queued an alert'; end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin if exists(select 1 from public.opportunities where id=(select id from push_test_context where key='opportunity')) then raise exception 'Pending opportunity public'; end if; end $$;
reset role;
select set_config('request.jwt.claims',json_build_object('sub',(select id from push_test_context where key='admin'),'role','authenticated')::text,true);
select public.admin_review_opportunity(id,'pending_review','approve','Push rollback test') from push_test_context where key in ('opportunity','demo','expired');
do $$ begin
 if (select count(*) from public.opportunity_push_events where opportunity_id in (select id from push_test_context))<>1 then raise exception 'Expected exactly one real, unexpired approval event'; end if;
 update public.opportunities set title='Edited public title' where id=(select id from push_test_context where key='opportunity');
 if (select count(*) from public.opportunity_push_events where opportunity_id=(select id from push_test_context where key='opportunity'))<>1 then raise exception 'Edit duplicated alert'; end if;
 if has_table_privilege('anon','public.opportunity_push_events','SELECT') or has_table_privilege('authenticated','public.opportunity_push_events','SELECT') then raise exception 'Queue exposed'; end if;
 if exists(select 1 from cron.job where jobname='op313-opportunity-push' and active) then raise exception 'Sender enabled without setup'; end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin if not exists(select 1 from public.opportunities where id=(select id from push_test_context where key='opportunity') and status='published') then raise exception 'Approved listing unavailable to Android public reader'; end if; end $$;
reset role;
set local role service_role;
do $$ declare event public.opportunity_push_events; begin
 select * into event from public.claim_opportunity_push_events() where opportunity_id=(select id from push_test_context where key='opportunity');
 if event.id is null or event.attempts<>1 then raise exception 'Claim failed'; end if;
 if public.finish_opportunity_push_event(event.id,gen_random_uuid(),'accepted') then raise exception 'Wrong lease completed'; end if;
 if not public.finish_opportunity_push_event(event.id,event.lease_id,'retry') then raise exception 'Retry failed'; end if;
 if not exists(select 1 from public.opportunity_push_events where id=event.id and status='pending' and next_attempt_at>now()) then raise exception 'Retry backoff missing'; end if;
 update public.opportunity_push_events set created_at=now()-interval '25 hours',next_attempt_at=now() where id=event.id;
 perform public.claim_opportunity_push_events();
 if not exists(select 1 from public.opportunity_push_events where id=event.id and status='skipped') then raise exception 'Old alerts not skipped'; end if;
end $$;
reset role;
rollback;
select 'PASS: provider direct publish denied, pending hidden, admin approval public, single alert, demo/expired excluded, private queue, inactive sender, lease/backoff, old alert suppression. All writes rolled back.' as result;
