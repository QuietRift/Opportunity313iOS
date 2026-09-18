begin;
create temporary table mvp_check_context (name text primary key, value uuid);
insert into mvp_check_context select role::text,user_id from public.user_roles where role in ('youth','parent','provider','admin');
insert into mvp_check_context values ('opportunity',gen_random_uuid());
insert into mvp_check_context select 'organization',organization_id from public.org_members where user_id=(select value from mvp_check_context where name='provider') and status='active' limit 1;
insert into mvp_check_context select 'youth_profile',id from public.youth_profiles where user_id=(select value from mvp_check_context where name='youth') limit 1;
grant select,insert on mvp_check_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='provider'),'role','authenticated')::text,true);
insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,starts_at,ends_at,deadline,cost_cents,is_free,location_name,registration_method,status,created_by)
select (select value from mvp_check_context where name='opportunity'),(select value from mvp_check_context where name='organization'),'Disposable MVP check','Rollback-only test of the agreed core opportunity flow.','Technology','Workshop',now()+interval '7 days',now()+interval '7 days 2 hours',now()+interval '6 days',0,true,'Test location','provider_submission','pending_review',auth.uid();
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='youth'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.opportunities where id=(select value from mvp_check_context where name='opportunity')) then raise exception 'Youth sees unpublished submission'; end if;
 begin
  perform public.publish_opportunity((select value from mvp_check_context where name='opportunity'));
  raise exception 'Youth publication unexpectedly permitted';
 exception when others then
  if SQLERRM <> 'Admin role required' then raise; end if;
 end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='admin'),'role','authenticated')::text,true);
do $$ begin
 if not exists(select 1 from public.opportunities where id=(select value from mvp_check_context where name='opportunity') and status='pending_review') then raise exception 'Admin queue missing submission'; end if;
end $$;
select public.verify_provider_organization((select value from mvp_check_context where name='organization'));
select public.publish_opportunity((select value from mvp_check_context where name='opportunity'));
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='youth'),'role','authenticated')::text,true);
do $$ begin
 if not exists(select 1 from public.opportunities where id=(select value from mvp_check_context where name='opportunity') and status='published' and verification_status='verified') then raise exception 'Youth discovery missing published submission'; end if;
end $$;
insert into public.opportunity_saves(youth_profile_id,opportunity_id) select (select value from mvp_check_context where name='youth_profile'),(select value from mvp_check_context where name='opportunity');
do $$ begin
 if not exists(select 1 from public.opportunity_saves s join public.opportunities o on o.id=s.opportunity_id where o.id=(select value from mvp_check_context where name='opportunity') and o.starts_at is not null and o.deadline is not null) then raise exception 'Youth saved calendar data missing'; end if;
end $$;
delete from public.opportunity_saves where opportunity_id=(select value from mvp_check_context where name='opportunity');
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='parent'),'role','authenticated')::text,true);
insert into mvp_check_context select 'child',public.create_parent_managed_youth('Disposable test child','14–18',8::smallint,array['Technology'],array[]::text[],'parent');
do $$ begin
 if not exists(select 1 from public.guardian_relationships where guardian_user_id=auth.uid() and youth_profile_id=(select value from mvp_check_context where name='child') and status='active') then raise exception 'Parent relationship missing'; end if;
 if not exists(select 1 from public.youth_profiles where id=(select value from mvp_check_context where name='child') and user_id is null and account_type='parent_managed') then raise exception 'Parent child missing'; end if;
end $$;
insert into public.opportunity_saves(youth_profile_id,opportunity_id) select (select value from mvp_check_context where name='child'),(select value from mvp_check_context where name='opportunity');
do $$ begin
 if not exists(select 1 from public.opportunity_saves s join public.opportunities o on o.id=s.opportunity_id where s.youth_profile_id=(select value from mvp_check_context where name='child') and o.starts_at is not null and o.deadline is not null) then raise exception 'Family calendar data missing'; end if;
end $$;
delete from public.opportunity_saves where youth_profile_id=(select value from mvp_check_context where name='child');
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='youth'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.youth_profiles where id=(select value from mvp_check_context where name='child')) then raise exception 'Unrelated youth can read child'; end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select value from mvp_check_context where name='provider'),'role','authenticated')::text,true);
do $$ begin
 if not exists(select 1 from public.opportunities where id=(select value from mvp_check_context where name='opportunity') and status='published') then raise exception 'Provider publication status missing'; end if;
end $$;
rollback;
select 'PASS: provider submission, admin review and publish, youth discovery/save/calendar/unsave, parent child/save/family calendar/unsave, role isolation. All test changes rolled back.' as result;
