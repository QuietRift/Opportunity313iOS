-- Unsubscribe preferences are separate from password recovery and security notices.
create table public.email_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 updates_enabled boolean not null default true,
 updated_at timestamptz not null default now()
);
alter table public.email_preferences enable row level security;
revoke all on public.email_preferences from public,anon,authenticated;
grant select,insert,update on public.email_preferences to authenticated;
grant all on public.email_preferences to service_role;
create policy email_preferences_select on public.email_preferences for select to authenticated using (user_id=(select auth.uid()));
create policy email_preferences_insert on public.email_preferences for insert to authenticated with check (user_id=(select auth.uid()));
create policy email_preferences_update on public.email_preferences for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create trigger email_preferences_updated before update on public.email_preferences for each row execute function public.set_updated_at();
do $$ begin
 if not exists(select 1 from vault.secrets where name='op313_email_unsubscribe_secret') then
  perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'op313_email_unsubscribe_secret');
 end if;
end $$;
create function private.email_delivery_preferences(recipient uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare secret text; enabled boolean;
begin
 if not exists(select 1 from auth.users where id=recipient) then return null; end if;
 select decrypted_secret into secret from vault.decrypted_secrets where name='op313_email_unsubscribe_secret';
 if secret is null then raise exception 'Unsubscribe signing unavailable'; end if;
 select updates_enabled into enabled from public.email_preferences where user_id=recipient;
 return jsonb_build_object('enabled',coalesce(enabled,true),'token',recipient::text||'.'||encode(extensions.hmac('optional-updates-v1:'||recipient::text,secret,'sha256'),'hex'));
end $$;
create function public.email_delivery_preferences(recipient uuid) returns jsonb
language sql security invoker set search_path='' as $$ select private.email_delivery_preferences(recipient) $$;
create function private.unsubscribe_email(token text,apply_change boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare recipient uuid; expected jsonb;
begin
 if token is null or token !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[0-9a-f]{64}$' then return false; end if;
 recipient:=split_part(token,'.',1)::uuid;
 expected:=private.email_delivery_preferences(recipient);
 if expected is null or expected->>'token'<>token then return false; end if;
 if apply_change then
  insert into public.email_preferences(user_id,updates_enabled) values(recipient,false)
  on conflict(user_id) do update set updates_enabled=false,updated_at=now();
 end if;
 return true;
end $$;
create function public.unsubscribe_email(token text,apply_change boolean default false) returns boolean
language sql security invoker set search_path='' as $$ select private.unsubscribe_email(token,apply_change) $$;
revoke all on function private.email_delivery_preferences(uuid),public.email_delivery_preferences(uuid),private.unsubscribe_email(text,boolean),public.unsubscribe_email(text,boolean) from public,anon,authenticated;
grant execute on function private.email_delivery_preferences(uuid),public.email_delivery_preferences(uuid),private.unsubscribe_email(text,boolean),public.unsubscribe_email(text,boolean) to service_role;

-- Revocation preserves the identity, tickets, school verification, saves and edits.
-- Only the server can suspend access; the parent ID comes from a verified session.
create function private.revoke_child_access(profile_id uuid,parent_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare child public.youth_profiles;
begin
 select * into child from public.youth_profiles where id=profile_id for update;
 if child.id is null or not exists(select 1 from public.guardian_relationships where youth_profile_id=profile_id and guardian_user_id=parent_id and status='active') then raise exception 'Active guardian required' using errcode='42501'; end if;
 if child.user_id=parent_id then raise exception 'Cannot revoke parent account'; end if;
 -- Preserve an email youth's identity for future access-code restoration, too.
 if child.user_id is not null then
  insert into public.child_access_credentials(youth_profile_id,auth_user_id,code_hash,code_hint,expires_at,revoked_at,created_by)
  values(profile_id,child.user_id,encode(extensions.gen_random_bytes(32),'hex'),'----',now(),now(),parent_id)
  on conflict(youth_profile_id) do update set revoked_at=now(),updated_at=now();
  delete from auth.sessions where user_id=child.user_id;
  delete from public.user_roles where user_id=child.user_id and role='youth';
 end if;
 update public.child_access_credentials set revoked_at=coalesce(revoked_at,now()) where youth_profile_id=profile_id;
 update public.youth_profiles set user_id=null,account_type='parent_managed' where id=profile_id;
 return true;
end $$;
create function public.revoke_child_access(profile_id uuid,parent_id uuid) returns boolean
language sql security invoker set search_path='' as $$ select private.revoke_child_access(profile_id,parent_id) $$;
revoke all on function private.revoke_child_access(uuid,uuid),public.revoke_child_access(uuid,uuid) from public,anon,authenticated;
grant execute on function private.revoke_child_access(uuid,uuid),public.revoke_child_access(uuid,uuid) to service_role;

-- A revoked credential must generate a revocation notice, never a creation notice.
create or replace function private.queue_access_email() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; guardian record; event text; template text;
begin
 if tg_op='DELETE' then target:=old.youth_profile_id; event:='access-revoke:'||target||':'||old.updated_at; template:='child_access_revoked';
 else
  if tg_op='UPDATE' and new.revoked_at is not distinct from old.revoked_at and new.code_hash is not distinct from old.code_hash then return new; end if;
  target:=new.youth_profile_id;
  template:=case when new.revoked_at is null then 'child_access_created' else 'child_access_revoked' end;
  event:=template||':'||target||':'||new.updated_at;
 end if;
 for guardian in select guardian_user_id from public.guardian_relationships where youth_profile_id=target and status='active' loop
  perform private.enqueue_email(guardian.guardian_user_id,event||':'||guardian.guardian_user_id,template);
 end loop;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;

-- Only permanent profile/account deletion runs this cleanup. Revocation never does.
create function private.erase_child_profile(profile_id uuid,skip_identity uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare child_identity uuid;
begin
 select coalesce(yp.user_id,c.auth_user_id) into child_identity from public.youth_profiles yp
 left join public.child_access_credentials c on c.youth_profile_id=yp.id where yp.id=profile_id for update of yp;
 delete from public.ticket_holds where assigned_youth_profile_id=profile_id;
 delete from public.tickets where assigned_youth_profile_id=profile_id;
 delete from public.youth_profiles where id=profile_id;
 -- Dedicated child identities are app-owned; independent email accounts are not.
 delete from auth.users where id=child_identity and id is distinct from skip_identity and raw_app_meta_data->>'account_kind'='parent_managed_child'
 and email='child-'||profile_id||'@access.opportunity313.invalid';
end $$;
create function private.delete_child_profile(profile_id uuid,parent_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.youth_profiles where id=profile_id for update;
 if not exists(select 1 from public.guardian_relationships where youth_profile_id=profile_id and guardian_user_id=parent_id and status='active') then raise exception 'Active guardian required' using errcode='42501'; end if;
 perform private.erase_child_profile(profile_id);
 return true;
end $$;
create function public.delete_child_profile(profile_id uuid,parent_id uuid) returns boolean
language sql security invoker set search_path='' as $$ select private.delete_child_profile(profile_id,parent_id) $$;
revoke all on function private.erase_child_profile(uuid,uuid),private.delete_child_profile(uuid,uuid),public.delete_child_profile(uuid,uuid) from public,anon,authenticated;
grant execute on function private.delete_child_profile(uuid,uuid),public.delete_child_profile(uuid,uuid) to service_role;

-- Remove user-owned data atomically with Auth Admin's hard deletion. No client RPC
-- accepts an arbitrary account ID for deletion. Shared guardian profiles survive.
alter table public.child_access_credentials alter column created_by drop not null;
alter table public.child_access_credentials drop constraint child_access_credentials_created_by_fkey;
alter table public.child_access_credentials add constraint child_access_credentials_created_by_fkey foreign key(created_by) references auth.users(id) on delete set null;
create function private.erase_deleted_account() returns trigger
language plpgsql security definer set search_path='' as $$
declare child record; org record;
begin
 for child in select yp.id from public.youth_profiles yp where yp.user_id=old.id or exists(
  select 1 from public.guardian_relationships g where g.youth_profile_id=yp.id and g.guardian_user_id=old.id
 ) order by yp.id for update loop
  if exists(select 1 from public.youth_profiles where id=child.id and user_id=old.id)
   or not exists(select 1 from public.guardian_relationships where youth_profile_id=child.id and guardian_user_id<>old.id and status='active') then
   perform private.erase_child_profile(child.id,old.id);
  end if;
 end loop;
 delete from public.tickets where claimed_by=old.id;
 delete from public.ticket_scans where scanned_by=old.id;
 delete from public.capacity_audit where actor=old.id;
 delete from public.student_school_verifications where requested_by=old.id;
 update public.student_school_verifications set verified_by=null where verified_by=old.id;
 -- A shared organization's records belong to its remaining members. Clear the
 -- departing contact's details; sole-member profiles and submissions are erased.
 for org in select o.id from public.organizations o join public.org_members m on m.organization_id=o.id where m.user_id=old.id order by o.id for update of o loop
  if not exists(select 1 from public.org_members where organization_id=org.id and user_id<>old.id and status='active') then
   delete from public.opportunities where organization_id=org.id;
   update public.organizations set name='Deleted organization',description=null,contact_name=null,contact_email=null,contact_phone=null,website=null,address=null,city=null,service_area=null,verification_status='pending',verified_at=null where id=org.id;
  else
   update public.organizations set contact_name=null,contact_email=null,contact_phone=null where id=org.id and lower(contact_email)=lower(old.email);
  end if;
 end loop;
 return old;
end $$;
revoke all on function private.erase_deleted_account() from public,anon,authenticated;
create trigger erase_deleted_account before delete on auth.users for each row execute function private.erase_deleted_account();

create function public.account_storage_objects(target_user uuid) returns table(bucket_id text,name text)
language sql security invoker set search_path='' as $$ select o.bucket_id,o.name from storage.objects o where o.owner_id=target_user::text or o.owner=target_user $$;
revoke all on function public.account_storage_objects(uuid) from public,anon,authenticated;
grant execute on function public.account_storage_objects(uuid) to service_role;

-- Reject stale JWTs for banned/revoked/deleted accounts on all REST/RPC paths,
-- including ticket APIs which don't consult youth-profile ownership.
create function private.check_account_access() returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then return; end if;
 if not exists(select 1 from auth.users where id=auth.uid() and (banned_until is null or banned_until<=now())) then
  raise exception 'Account access is no longer available. Sign in again.' using errcode='42501';
 end if;
end $$;
create function public.check_account_access() returns void
language sql security invoker set search_path='' as $$ select private.check_account_access() $$;
revoke all on function private.check_account_access(),public.check_account_access() from public;
grant usage on schema private to anon;
grant execute on function private.check_account_access(),public.check_account_access() to anon,authenticated,service_role;
alter role authenticator set pgrst.db_pre_request='public.check_account_access';
notify pgrst,'reload config';
