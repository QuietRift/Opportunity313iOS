-- Operational notifications only; no backfill or marketing sends.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create table public.transactional_emails (
 id uuid primary key default gen_random_uuid(),
 recipient_user_id uuid not null references auth.users(id) on delete cascade,
 event_key text not null unique,
 kind text not null check (kind in ('parent_welcome','provider_welcome','child_added','child_access_created','child_access_revoked','submission_pending','submission_approved','submission_rejected','submission_paused','organization_verified')),
 payload jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check (status in ('pending','sending','accepted','failed','skipped')),
 attempts integer not null default 0,
 next_attempt_at timestamptz not null default now(),
 lease_id uuid,
 lease_until timestamptz,
 provider_message_id text,
 last_error text,
 created_at timestamptz not null default now(),
 accepted_at timestamptz
);
alter table public.transactional_emails enable row level security;
revoke all on public.transactional_emails from public,anon,authenticated;
grant select,update,insert,delete on public.transactional_emails to service_role;
create index transactional_emails_ready on public.transactional_emails(next_attempt_at,created_at) where status in ('pending','sending');
create index transactional_emails_recipient on public.transactional_emails(recipient_user_id);

create or replace function private.enqueue_email(recipient uuid,event text,template text,details jsonb default '{}') returns void
language sql security definer set search_path='' as $$
 insert into public.transactional_emails(recipient_user_id,event_key,kind,payload)
 select recipient,event,template,details from auth.users u
 where u.id=recipient and u.email_confirmed_at is not null and u.email is not null
 and u.email not like '%.invalid' and (u.banned_until is null or u.banned_until<now())
 on conflict(event_key) do nothing;
$$;
revoke all on function private.enqueue_email(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace function private.queue_account_email() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.role::text in ('parent','provider') then
  perform private.enqueue_email(new.user_id,'welcome:'||new.user_id||':'||new.role::text,new.role::text||'_welcome');
 end if;
 return new;
end $$;
create trigger queue_account_email after insert on public.user_roles for each row execute function private.queue_account_email();

create or replace function private.queue_child_email() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status::text='active' then
  perform private.enqueue_email(new.guardian_user_id,'child:'||new.id,'child_added');
 end if;
 return new;
end $$;
create trigger queue_child_email after insert on public.guardian_relationships for each row execute function private.queue_child_email();

create or replace function private.queue_access_email() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; guardian record; event text; template text;
begin
 if tg_op='DELETE' then target:=old.youth_profile_id; event:='access-revoke:'||old.youth_profile_id||':'||old.updated_at; template:='child_access_revoked';
 else target:=new.youth_profile_id; event:='access-create:'||new.youth_profile_id||':'||new.updated_at; template:='child_access_created'; end if;
 for guardian in select guardian_user_id from public.guardian_relationships where youth_profile_id=target and status='active' loop
  perform private.enqueue_email(guardian.guardian_user_id,event||':'||guardian.guardian_user_id,template);
 end loop;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger queue_access_email after insert or update or delete on public.child_access_credentials for each row execute function private.queue_access_email();

create or replace function private.queue_provider_email() returns trigger
language plpgsql security definer set search_path='' as $$
declare template text; event text; member record; target_org uuid;
begin
 if new.is_demo then return new; end if;
 if tg_table_name='organizations' then
  if old.verification_status is not distinct from new.verification_status or new.verification_status::text<>'verified' then return new; end if;
  target_org:=new.id; template:='organization_verified'; event:='org-verified:'||new.id||':'||new.updated_at;
 else
  if tg_op='UPDATE' and old.status is not distinct from new.status and old.verification_status is not distinct from new.verification_status then return new; end if;
  if new.status::text='pending_review' then template:='submission_pending';
  elsif new.status::text='published' then template:='submission_approved';
  elsif new.verification_status::text='rejected' then template:='submission_rejected';
  elsif new.status::text='paused' then template:='submission_paused';
  else return new; end if;
  target_org:=new.organization_id;
  event:='opportunity:'||new.id||':'||new.updated_at||':'||template;
 end if;
 for member in select user_id from public.org_members where organization_id=target_org and status='active' loop
  -- The recipient is an authenticated member, never a user-entered contact email.
  if tg_table_name='organizations' then
   perform private.enqueue_email(member.user_id,event||':'||member.user_id,template,jsonb_build_object('title',new.name));
  else
   perform private.enqueue_email(member.user_id,event||':'||member.user_id,template,jsonb_build_object('title',new.title));
  end if;
 end loop;
 return new;
end $$;
create trigger queue_provider_opportunity_email after insert or update on public.opportunities for each row execute function private.queue_provider_email();
create trigger queue_organization_email after update on public.organizations for each row execute function private.queue_provider_email();

-- Trigger functions are not public APIs.
revoke all on function private.queue_account_email(),private.queue_child_email(),private.queue_access_email(),private.queue_provider_email() from public,anon,authenticated;

create or replace function public.claim_transactional_emails(batch_size integer default 5) returns setof public.transactional_emails
language sql security invoker set search_path='' as $$
 with exhausted as (update public.transactional_emails set status='failed',last_error='lease_expired' where status='sending' and lease_until<now() and attempts>=6 returning id)
 update public.transactional_emails e set status='sending', attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes'
 where id in (select id from public.transactional_emails where
 ((status='pending' and next_attempt_at<=now()) or (status='sending' and lease_until<now())) and attempts<6
 order by created_at for update skip locked limit least(greatest(batch_size,1),5)) returning e.*;
$$;
create or replace function public.finish_transactional_email(target_id uuid,target_lease uuid,result text,message_id text default null,error_code text default null) returns boolean
language plpgsql security invoker set search_path='' as $$
declare changed integer;
begin
 if result not in ('accepted','retry','failed','skipped') then raise exception 'Invalid result'; end if;
 update public.transactional_emails set
 status=case when result='retry' then case when attempts>=6 then 'failed' else 'pending' end else result end,
 next_attempt_at=now()+make_interval(secs=>least(3600,60*(2^attempts)::integer)),lease_until=null,lease_id=null,
 provider_message_id=message_id,last_error=left(error_code,100),accepted_at=case when result='accepted' then now() else null end
 where id=target_id and lease_id=target_lease and status='sending';
 get diagnostics changed=row_count;
 return changed=1;
end $$;
revoke all on function public.claim_transactional_emails(integer),public.finish_transactional_email(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.claim_transactional_emails(integer),public.finish_transactional_email(uuid,uuid,text,text,text) to service_role;

-- A project-private dispatch credential is generated and retained only in Vault.
do $$ begin
 if not exists(select 1 from vault.secrets where name='op313_email_worker_secret') then
  perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'op313_email_worker_secret','Internal scheduled email dispatch');
 end if;
end $$;
create or replace function private.email_worker_secret() returns text language sql security definer set search_path='' as $$
 select decrypted_secret from vault.decrypted_secrets where name='op313_email_worker_secret' limit 1;
$$;
revoke all on function private.email_worker_secret() from public,anon,authenticated;
grant usage on schema private to service_role;
grant execute on function private.email_worker_secret() to service_role;
create or replace function public.email_worker_secret() returns text language sql security invoker set search_path='' as $$ select private.email_worker_secret(); $$;
revoke all on function public.email_worker_secret() from public,anon,authenticated;
grant execute on function public.email_worker_secret() to service_role;

create or replace function private.dispatch_transactional_emails() returns bigint
language plpgsql security definer set search_path='' as $$
begin
 return net.http_post(
 url:='https://pinpurdjfbvxrwexzlre.supabase.co/functions/v1/transactional-email',
 headers:=jsonb_build_object('Content-Type','application/json','x-email-worker-secret',private.email_worker_secret()),
 body:='{}'::jsonb,timeout_milliseconds:=10000);
end $$;
revoke all on function private.dispatch_transactional_emails() from public,anon,authenticated;
select cron.schedule('op313-transactional-emails','*/2 * * * *','select private.dispatch_transactional_emails();');

-- Activate after the sender and actual delivery are verified.
select cron.alter_job(jobid,active:=false) from cron.job where jobname='op313-transactional-emails';
