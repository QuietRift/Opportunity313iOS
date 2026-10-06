begin;
create temp table email_qa(key text primary key,id uuid not null default gen_random_uuid());
insert into email_qa(key) values('parent'),('provider'),('org'),('opportunity');
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select id,'authenticated','authenticated',key||'-email-rollback@example.org',now(),'{}','{}',now(),now() from email_qa where key in ('parent','provider');
insert into public.user_roles(user_id,role) select id,key::public.app_role from email_qa where key in ('parent','provider');
insert into public.organizations(id,name,organization_type) select id,'Rollback email organization','nonprofit' from email_qa where key='org';
insert into public.org_members(organization_id,user_id,role,status) values((select id from email_qa where key='org'),(select id from email_qa where key='provider'),'owner','active');
insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,location_name,registration_method,status,created_by)
values((select id from email_qa where key='opportunity'),(select id from email_qa where key='org'),'Rollback email opportunity','Email queue test','Technology','Workshop','Detroit','provider_submission','pending_review',(select id from email_qa where key='provider'));
update public.opportunities set title='Edited title' where id=(select id from email_qa where key='opportunity');
update public.opportunities set status='published',verification_status='verified' where id=(select id from email_qa where key='opportunity');
update public.opportunities set status='closed',verification_status='rejected' where id=(select id from email_qa where key='opportunity');
update public.organizations set verification_status='verified' where id=(select id from email_qa where key='org');
do $$ declare c integer; begin
 select count(*) into c from public.transactional_emails where recipient_user_id in(select id from email_qa where key in('parent','provider'));
 if c<>6 then raise exception 'Expected 6 role/submission/verification emails, got %',c; end if;
 if exists(select 1 from public.transactional_emails where recipient_user_id=(select id from email_qa where key='parent') and kind like 'submission_%') then raise exception 'Provider notification sent to parent'; end if;
 if has_function_privilege('anon','public.email_worker_secret()','execute') or has_function_privilege('authenticated','public.claim_transactional_emails(integer)','execute') then raise exception 'Worker APIs exposed'; end if;
 if has_table_privilege('authenticated','public.transactional_emails','select') or has_table_privilege('anon','public.transactional_emails','insert') then raise exception 'Queue exposed'; end if;
 if exists(select 1 from cron.job where jobname='op313-transactional-emails' and active) then raise exception 'Sender activated before setup'; end if;
end $$;
-- Guardian insertion and credential creation/revocation enqueue notifications without codes.
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from email_qa where key='parent'),'role','authenticated')::text,true);
insert into email_qa(key,id) values('child',public.create_parent_managed_youth('Rollback Child','9-12',4::smallint,'girl','{}','{}','parent'));
insert into public.child_access_credentials(youth_profile_id,auth_user_id,code_hash,code_hint,created_by) values((select id from email_qa where key='child'),(select id from email_qa where key='parent'),repeat('a',64),'TEST',(select id from email_qa where key='parent'));
delete from public.child_access_credentials where youth_profile_id=(select id from email_qa where key='child');
do $$ begin
 if (select count(*) from public.transactional_emails where recipient_user_id=(select id from email_qa where key='parent'))<>4 then raise exception 'Child event notifications missing'; end if;
 if exists(select 1 from public.transactional_emails where payload::text like '%rollback-hash%' or payload::text like '%TEST%') then raise exception 'Code leaked into notification'; end if;
end $$;
set local role service_role;
do $$ declare e public.transactional_emails; count_claimed integer:=0; begin
 for e in select * from public.claim_transactional_emails(5) loop
  count_claimed:=count_claimed+1;
  if public.finish_transactional_email(e.id,gen_random_uuid(),'accepted','bad') then raise exception 'Wrong lease accepted'; end if;
  if not public.finish_transactional_email(e.id,e.lease_id,'retry',null,'fixture_503') then raise exception 'Retry failed'; end if;
  if public.finish_transactional_email(e.id,e.lease_id,'accepted','duplicate') then raise exception 'Stale lease accepted'; end if;
 end loop;
 if count_claimed<>5 then raise exception 'Expected bounded batch'; end if;
 if exists(select 1 from public.transactional_emails where last_error='fixture_503' and (status<>'pending' or attempts<>1 or next_attempt_at<=now())) then raise exception 'Backoff incorrect'; end if;
end $$;
reset role;
rollback;
select 'PASS: account, child/access, provider status/verification events; recipient isolation; no codes; restricted worker; leases/backoff; no live sends. All test changes rolled back.' as result;
