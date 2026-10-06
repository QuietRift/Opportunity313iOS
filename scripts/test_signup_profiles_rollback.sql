begin;
create temp table signup_test_context as
select role::text as role, min(user_id::text)::uuid as id from public.user_roles where role in ('parent','provider') group by role;
grant select on signup_test_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',(select id from signup_test_context where role='parent'),'role','authenticated')::text,true);
do $$ declare before_count integer; after_count integer; touched integer; begin
 if auth.uid() is null then raise exception 'Parent fixture missing'; end if;
 select count(*) into before_count from public.user_roles where user_id=auth.uid() and role='parent';
 perform public.claim_onboarding_role('parent');
 perform public.claim_onboarding_role('parent');
 select count(*) into after_count from public.user_roles where user_id=auth.uid() and role='parent';
 if after_count<>1 or before_count<>1 then raise exception 'Parent role retry failed'; end if;
 update public.profiles set display_name='Rollback Parent Signup',neighborhood=null where user_id=auth.uid();
 get diagnostics touched=row_count;
 if touched<>1 or not exists(select 1 from public.profiles where user_id=auth.uid() and display_name='Rollback Parent Signup' and neighborhood is null) then raise exception 'Parent profile save failed'; end if;
 update public.profiles set display_name='Unauthorized' where user_id=(select id from signup_test_context where role='provider');
 get diagnostics touched=row_count;
 if touched<>0 then raise exception 'Cross-account parent profile update succeeded'; end if;
 begin
  perform public.claim_onboarding_role('admin');
  raise exception 'Admin role could be self-assigned';
 exception when others then if SQLERRM<>'This role cannot be self-assigned' then raise; end if; end;
end $$;
rollback;
select 'PASS: parent role retries, own profile update and optional clearing, cross-account update denied, admin role denied. All changes rolled back.' as result;
