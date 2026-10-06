-- Parent-managed profiles may link the dedicated, server-created child identity.
alter table public.youth_profiles drop constraint youth_account_owner_check;
alter table public.youth_profiles add constraint youth_account_owner_check check (
 account_type='parent_managed' or (account_type='youth_account' and user_id is not null)
);
create or replace function private.check_managed_child_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.account_type='parent_managed' and new.user_id is not null and not exists(
  select 1 from auth.users where id=new.user_id
  and raw_app_meta_data->>'account_kind'='parent_managed_child'
  and email='child-'||new.id||'@access.opportunity313.invalid'
 ) then raise exception 'A parent-managed profile requires a dedicated child access identity' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.check_managed_child_identity() from public,anon,authenticated;
create trigger check_managed_child_identity before insert or update of user_id,account_type on public.youth_profiles for each row execute function private.check_managed_child_identity();

-- Client users cannot relink ownership or turn a managed profile into an adult one.
revoke update on public.youth_profiles from authenticated;
grant update(first_name,age_band,grade,gender,interests,accessibility_preferences) on public.youth_profiles to authenticated;
create or replace function private.limit_managed_child_edits() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if current_user='authenticated' and old.account_type='parent_managed' and old.user_id=auth.uid()
 and not public.has_role(auth.uid(),'admin') then
  if (to_jsonb(new)-'interests'-'updated_at') is distinct from (to_jsonb(old)-'interests'-'updated_at') then
   raise exception 'Only a parent or guardian can change this profile information' using errcode='42501';
  end if;
 end if;
 return new;
end $$;
revoke all on function private.limit_managed_child_edits() from public,anon,authenticated;
create trigger limit_managed_child_edits before update on public.youth_profiles for each row execute function private.limit_managed_child_edits();
drop policy guardian_relationships_update_scoped on public.guardian_relationships;
create policy guardian_relationships_update_scoped on public.guardian_relationships for update to authenticated
 using ((guardian_user_id=(select auth.uid()) and public.has_role((select auth.uid()),'parent')) or public.has_role((select auth.uid()),'admin'))
 with check ((guardian_user_id=(select auth.uid()) and public.has_role((select auth.uid()),'parent')) or public.has_role((select auth.uid()),'admin'));
