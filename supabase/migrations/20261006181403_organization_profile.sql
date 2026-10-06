-- Applied as the organization_profile Supabase migration. Organization is the UI
-- name for the existing provider role; no duplicate roles or memberships are created.
alter table public.organizations add column if not exists service_area text;
alter table public.organizations add column if not exists address text;
alter table public.organizations add column if not exists city text;

-- Organization managers must never self-verify or change record identity.
revoke update on public.organizations from authenticated;
grant update (name, organization_type, description, contact_name, contact_email,
 contact_phone, website, service_area, address, city) on public.organizations to authenticated;

create or replace function private.save_organization_profile(target_organization_id uuid, profile jsonb)
returns public.organizations language plpgsql security definer set search_path = '' as $$
declare
 result public.organizations;
 clean_name text := btrim(profile->>'name');
 clean_website text := nullif(btrim(profile->>'website'), '');
 clean_email text := nullif(btrim(profile->>'contact_email'), '');
 field_value text;
begin
 if auth.uid() is null or not public.has_role(auth.uid(), 'provider') then
  raise exception 'Organization account required' using errcode = '42501';
 end if;
 if clean_name is null or char_length(clean_name) not between 3 and 200 then
  raise exception 'Organization name must be between 3 and 200 characters';
 end if;
 if profile->>'organization_type' is null then raise exception 'Organization type required'; end if;
 for field_value in select value from jsonb_each_text(profile) loop
  if char_length(field_value) > 2000 then raise exception 'Profile fields must be 2,000 characters or fewer'; end if;
 end loop;
 if clean_website is not null and clean_website !~* '^https?://[^[:space:]/@]+([/?#][^[:space:]]*)?$' then
  raise exception 'Website must be an http or https URL';
 end if;
 if clean_email is not null and clean_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
  raise exception 'Invalid contact email';
 end if;
 if target_organization_id is null then
  -- Serialize retries for the same account so a lost response cannot duplicate setup.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  if exists(select 1 from public.org_members where user_id=auth.uid() and status='active') then
   raise exception 'An organization already exists for this account. Reload your profile.';
  end if;
  select * into result from public.register_provider_organization(
   clean_name, (profile->>'organization_type')::public.organization_type, nullif(btrim(profile->>'description'), ''));
  target_organization_id := result.id;
 elsif not exists(select 1 from public.org_members where organization_id=target_organization_id
  and user_id=auth.uid() and status='active') then
  raise exception 'Active organization membership required' using errcode = '42501';
 end if;
 update public.organizations set
  name=clean_name, organization_type=(profile->>'organization_type')::public.organization_type,
  description=nullif(btrim(profile->>'description'), ''), website=clean_website,
  contact_name=nullif(btrim(profile->>'contact_name'), ''), contact_email=clean_email,
  contact_phone=nullif(btrim(profile->>'contact_phone'), ''),
  service_area=nullif(btrim(profile->>'service_area'), ''),
  address=nullif(btrim(profile->>'address'), ''), city=nullif(btrim(profile->>'city'), '')
 where id=target_organization_id returning * into result;
 if not found then raise exception 'Organization no longer exists'; end if;
 return result;
end;
$$;
revoke all on function private.save_organization_profile(uuid,jsonb) from public, anon;
grant execute on function private.save_organization_profile(uuid,jsonb) to authenticated;
create or replace function public.save_organization_profile(target_organization_id uuid, profile jsonb)
returns public.organizations language sql security invoker set search_path = '' as $$
 select private.save_organization_profile(target_organization_id, profile);
$$;
revoke all on function public.save_organization_profile(uuid,jsonb) from public, anon;
grant execute on function public.save_organization_profile(uuid,jsonb) to authenticated;
