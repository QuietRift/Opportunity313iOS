-- Public opportunity alerts only. No backfill; no pending submissions or private child data.
create table public.opportunity_push_events (
 id uuid primary key default gen_random_uuid(),
 opportunity_id uuid not null unique references public.opportunities(id) on delete cascade,
 status text not null default 'pending' check (status in ('pending','sending','accepted','failed','skipped')),
 attempts integer not null default 0,
 next_attempt_at timestamptz not null default now(),
 lease_id uuid, lease_until timestamptz,
 provider_message_id text, last_error text,
 created_at timestamptz not null default now(), accepted_at timestamptz
);
alter table public.opportunity_push_events enable row level security;
revoke all on public.opportunity_push_events from public,anon,authenticated;
grant select,insert,update,delete on public.opportunity_push_events to service_role;
create index opportunity_push_events_ready on public.opportunity_push_events(next_attempt_at,created_at) where status in ('pending','sending');

create or replace function private.enqueue_opportunity_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status='published' and not new.is_demo and (new.deadline is null or new.deadline>=now())
  and (tg_op='INSERT' or old.status is distinct from new.status) then
  insert into public.opportunity_push_events(opportunity_id) values(new.id) on conflict(opportunity_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function private.enqueue_opportunity_push() from public,anon,authenticated;
create trigger opportunity_publication_alert after insert or update of status on public.opportunities
 for each row execute function private.enqueue_opportunity_push();

create or replace function public.claim_opportunity_push_events() returns setof public.opportunity_push_events
language plpgsql security invoker set search_path='' as $$
begin
 update public.opportunity_push_events e set status='skipped',lease_id=null,lease_until=null,last_error='no_longer_public'
 where e.status in ('pending','sending') and (e.status='pending' or e.lease_until<now()) and
 (e.created_at<now()-interval '24 hours' or not exists(select 1 from public.opportunities o where o.id=e.opportunity_id and o.status='published' and not o.is_demo and (o.deadline is null or o.deadline>=now())));
 update public.opportunity_push_events set status='failed',last_error='lease_expired' where status='sending' and lease_until<now() and attempts>=6;
 return query update public.opportunity_push_events e set status='sending',attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes'
 where id in (select id from public.opportunity_push_events where
 ((status='pending' and next_attempt_at<=now()) or (status='sending' and lease_until<now())) and attempts<6
 order by created_at for update skip locked limit 5) returning e.*;
end $$;
create or replace function public.finish_opportunity_push_event(target_id uuid,target_lease uuid,result text,message_id text default null,error_code text default null) returns boolean
language plpgsql security invoker set search_path='' as $$
declare changed integer;
begin
 if result not in ('accepted','retry','failed','skipped') then raise exception 'Invalid result'; end if;
 update public.opportunity_push_events set
 status=case when result='retry' then case when attempts>=6 then 'failed' else 'pending' end else result end,
 next_attempt_at=now()+make_interval(secs=>least(3600,60*(2^attempts)::integer)),lease_until=null,lease_id=null,
 provider_message_id=message_id,last_error=left(error_code,100),accepted_at=case when result='accepted' then now() else null end
 where id=target_id and lease_id=target_lease and status='sending';
 get diagnostics changed=row_count;
 return changed=1;
end $$;
revoke all on function public.claim_opportunity_push_events(),public.finish_opportunity_push_event(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.claim_opportunity_push_events(),public.finish_opportunity_push_event(uuid,uuid,text,text,text) to service_role;

do $$ begin
 if not exists(select 1 from vault.secrets where name='op313_push_worker_secret') then
  perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'op313_push_worker_secret','Private scheduled opportunity alerts');
 end if;
end $$;
create or replace function private.push_worker_secret() returns text language sql security definer set search_path='' as $$
 select decrypted_secret from vault.decrypted_secrets where name='op313_push_worker_secret' limit 1;
$$;
revoke all on function private.push_worker_secret() from public,anon,authenticated;
grant execute on function private.push_worker_secret() to service_role;
create or replace function public.push_worker_secret() returns text language sql security invoker set search_path='' as $$ select private.push_worker_secret(); $$;
revoke all on function public.push_worker_secret() from public,anon,authenticated;
grant execute on function public.push_worker_secret() to service_role;
create or replace function private.dispatch_opportunity_push() returns bigint
language plpgsql security definer set search_path='' as $$
begin
 return net.http_post(
 url:='https://pinpurdjfbvxrwexzlre.supabase.co/functions/v1/opportunity-push',
 headers:=jsonb_build_object('Content-Type','application/json','x-push-worker-secret',private.push_worker_secret()),body:='{}'::jsonb,timeout_milliseconds:=10000);
end $$;
revoke all on function private.dispatch_opportunity_push() from public,anon,authenticated;
select cron.schedule('op313-opportunity-push','* * * * *','select private.dispatch_opportunity_push();');
-- Enable only after Firebase/APNs configuration and real device delivery checks.
select cron.alter_job(jobid,active:=false) from cron.job where jobname='op313-opportunity-push';
