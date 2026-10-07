begin;
create temp table privacy_qa(key text primary key,id uuid default gen_random_uuid());
insert into privacy_qa(key) values('parent'),('guardian'),('other'),('provider'),('org'),('opp'),('child-user');
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select id,'authenticated','authenticated',key||'-privacy-rollback@example.org',now(),'{}','{}',now(),now() from privacy_qa where key in('parent','guardian','other','provider');
insert into public.user_roles(user_id,role) select id,case when key='provider' then 'provider'::public.app_role else 'parent'::public.app_role end from privacy_qa where key in('parent','guardian','provider');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from privacy_qa where key='parent'),'role','authenticated')::text,true);
insert into privacy_qa(key,id) values('child',public.create_parent_managed_youth('Keep My Changes','9-12',4::smallint,'girl',array['Technology'],array['Quiet space'],'parent'));
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select id,'authenticated','authenticated','child-'||(select id from privacy_qa where key='child')||'@access.opportunity313.invalid',now(),'{"account_kind":"parent_managed_child"}','{}',now(),now() from privacy_qa where key='child-user';
update public.youth_profiles set user_id=(select id from privacy_qa where key='child-user') where id=(select id from privacy_qa where key='child');
insert into public.user_roles(user_id,role) select id,'youth' from privacy_qa where key='child-user';
insert into public.child_access_credentials(youth_profile_id,auth_user_id,code_hash,code_hint,expires_at,created_by)
values((select id from privacy_qa where key='child'),(select id from privacy_qa where key='child-user'),repeat('b',64),'TEST',now()+interval '180 days',(select id from privacy_qa where key='parent'));
insert into public.organizations(id,name,organization_type,contact_email) select id,'Privacy Fixture','nonprofit','provider-privacy-rollback@example.org' from privacy_qa where key='org';
insert into public.org_members(organization_id,user_id,role,status) values((select id from privacy_qa where key='org'),(select id from privacy_qa where key='provider'),'owner','active');
insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,location_name,registration_method,status,created_by)
values((select id from privacy_qa where key='opp'),(select id from privacy_qa where key='org'),'Privacy Fixture','Fixture','Technology','Workshop','Detroit','provider_submission','pending_review',(select id from privacy_qa where key='provider'));
insert into public.opportunity_saves(youth_profile_id,opportunity_id) values((select id from privacy_qa where key='child'),(select id from privacy_qa where key='opp'));
do $$ declare token text; begin
 token:=public.email_delivery_preferences((select id from privacy_qa where key='parent'))->>'token';
 if not public.unsubscribe_email(token,false) then raise exception 'Valid GET failed'; end if;
 if exists(select 1 from public.email_preferences where user_id=(select id from privacy_qa where key='parent')) then raise exception 'GET mutated preferences'; end if;
 if public.unsubscribe_email(token||'0',true) then raise exception 'Forged token accepted'; end if;
 if not public.unsubscribe_email(token,true) or not public.unsubscribe_email(token,true) then raise exception 'Unsubscribe not idempotent'; end if;
 if (public.email_delivery_preferences((select id from privacy_qa where key='parent'))->>'enabled')::boolean then raise exception 'Opt out not saved'; end if;
 if not (public.email_delivery_preferences((select id from privacy_qa where key='other'))->>'enabled')::boolean then raise exception 'Other user opted out'; end if;
 if has_function_privilege('authenticated','public.delete_child_profile(uuid,uuid)','execute') or has_function_privilege('anon','public.email_delivery_preferences(uuid)','execute') then raise exception 'Server functions exposed'; end if;
end $$;
-- Parent-scoped preferences cannot read/write someone else's settings.
grant select on privacy_qa to authenticated;
set local role authenticated;
do $$ begin
 begin
  insert into public.email_preferences(user_id,updates_enabled) values((select id from privacy_qa where key='other'),false);
  raise exception 'Cross-account preference write accepted';
 exception when insufficient_privilege then null; end;
 update public.email_preferences set updates_enabled=true where user_id=(select id from privacy_qa where key='parent');
 if (select count(*) from public.email_preferences)<>1 then raise exception 'Preferences RLS incorrect'; end if;
end $$;
reset role;
-- Revoke access: preserve edits, saves, identity; disconnect ownership and role.
update auth.users set banned_until=now()+interval '100 years' where id=(select id from privacy_qa where key='child-user');
select public.revoke_child_access((select id from privacy_qa where key='child'),(select id from privacy_qa where key='parent'));
do $$ begin
 if not exists(select 1 from public.youth_profiles where id=(select id from privacy_qa where key='child') and first_name='Keep My Changes' and interests=array['Technology'] and accessibility_preferences=array['Quiet space'] and user_id is null) then raise exception 'Revocation lost profile edits'; end if;
 if not exists(select 1 from public.opportunity_saves where youth_profile_id=(select id from privacy_qa where key='child')) then raise exception 'Revocation lost saves'; end if;
 if not exists(select 1 from auth.users where id=(select id from privacy_qa where key='child-user')) then raise exception 'Revocation deleted identity'; end if;
 if not exists(select 1 from public.child_access_credentials where youth_profile_id=(select id from privacy_qa where key='child') and revoked_at is not null and auth_user_id=(select id from privacy_qa where key='child-user')) then raise exception 'Revoked identity lost'; end if;
 if exists(select 1 from public.user_roles where user_id=(select id from privacy_qa where key='child-user')) then raise exception 'Revoked child retained role'; end if;
 begin
  perform public.delete_child_profile((select id from privacy_qa where key='child'),(select id from privacy_qa where key='other'));
  raise exception 'Unrelated guardian deletion accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from privacy_qa where key='child-user'),'role','authenticated')::text,true);
do $$ begin
 begin perform public.check_account_access(); raise exception 'Banned JWT accepted'; exception when insufficient_privilege then null; end;
end $$;
-- Restoring the same identity keeps the same profile/saves.
update auth.users set banned_until=null where id=(select id from privacy_qa where key='child-user');
update public.youth_profiles set user_id=(select id from privacy_qa where key='child-user') where id=(select id from privacy_qa where key='child');
update public.child_access_credentials set revoked_at=null where youth_profile_id=(select id from privacy_qa where key='child');
select public.check_account_access();
-- Shared child remains when one guardian deletes their account.
insert into public.guardian_relationships(guardian_user_id,youth_profile_id,relationship,status) values((select id from privacy_qa where key='guardian'),(select id from privacy_qa where key='child'),'parent','active');
delete from auth.users where id=(select id from privacy_qa where key='parent');
do $$ begin
 if not exists(select 1 from public.youth_profiles where id=(select id from privacy_qa where key='child')) then raise exception 'Shared child removed'; end if;
end $$;
-- Permanent deletion removes profile, saves, guardian links, credential and identity.
select public.delete_child_profile((select id from privacy_qa where key='child'),(select id from privacy_qa where key='guardian'));
do $$ begin
 if exists(select 1 from public.youth_profiles where id=(select id from privacy_qa where key='child')) or exists(select 1 from public.opportunity_saves where youth_profile_id=(select id from privacy_qa where key='child')) or exists(select 1 from auth.users where id=(select id from privacy_qa where key='child-user')) then raise exception 'Permanent profile cleanup incomplete'; end if;
 begin perform public.check_account_access(); raise exception 'Deleted JWT accepted'; exception when insufficient_privilege then null; end;
end $$;
delete from auth.users where id=(select id from privacy_qa where key='provider');
do $$ begin
 if exists(select 1 from public.opportunities where id=(select id from privacy_qa where key='opp')) then raise exception 'Sole provider content retained'; end if;
 if not exists(select 1 from public.organizations where id=(select id from privacy_qa where key='org') and name='Deleted organization' and contact_email is null) then raise exception 'Sole provider PII retained'; end if;
end $$;
rollback;
select 'PASS: unsubscribe validation/idempotence/RLS, revocation preserves changes/saves/identity, restore, shared guardian preservation, permanent child/account deletion, provider cleanup, banned/deleted JWT rejection. All changes rolled back.' as result;
