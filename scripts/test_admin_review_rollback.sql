begin;
create temp table admin_test_context(key text primary key, id uuid);
insert into admin_test_context select distinct on(role) role::text,user_id from public.user_roles where role in ('admin','youth','provider','parent') order by role,user_id;
insert into admin_test_context values ('opportunity',gen_random_uuid()),('organization',gen_random_uuid());
insert into public.organizations(id,name,organization_type,verification_status) select id,'Disposable admin test','community_provider','pending' from admin_test_context where key='organization';
insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,starts_at,cost_cents,is_free,location_name,registration_method,status)
select (select id from admin_test_context where key='opportunity'),(select id from admin_test_context where key='organization'),'Disposable admin test','Rollback-only admin workflow verification.','Technology','Workshop',null,0,true,'Test location','provider_submission','pending_review';
grant select on admin_test_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',(select id from admin_test_context where key='admin'),'role','authenticated')::text,true);
do $$ declare oid uuid := (select id from admin_test_context where key='opportunity'); begin
 begin
   perform public.admin_review_opportunity(oid,'pending_review','approve','');
   raise exception 'Invalid publication succeeded';
 exception when others then
   if SQLERRM <> 'Opportunity is missing required fields or cannot be published from its current state' then raise; end if;
 end;
 if exists(select 1 from public.organizations where id=(select id from admin_test_context where key='organization') and verification_status='verified') then raise exception 'Partial verification escaped rollback'; end if;
 begin
   perform public.admin_review_opportunity(oid,'pending_review','reject','   ');
   raise exception 'Blank rejection succeeded';
 exception when others then if SQLERRM <> 'A review reason is required' then raise; end if; end;
 perform public.admin_review_opportunity(oid,'pending_review','reject','Missing schedule');
 if not exists(select 1 from public.opportunities where id=oid and status='closed' and verification_status='rejected') then raise exception 'Rejection missing'; end if;
 begin
   perform public.admin_review_opportunity(oid,'pending_review','approve','');
   raise exception 'Stale decision succeeded';
 exception when others then if SQLERRM <> 'This opportunity changed. Refresh and review its current status.' then raise; end if; end;
 perform public.admin_review_opportunity(oid,'closed','requeue','Schedule corrected');
end $$;
reset role;
update public.opportunities set starts_at=now()+interval '7 days' where id=(select id from admin_test_context where key='opportunity');
set local role authenticated;
do $$ declare oid uuid := (select id from admin_test_context where key='opportunity'); counts jsonb; begin
 perform public.admin_review_opportunity(oid,'pending_review','approve','Reviewed');
 if not exists(select 1 from public.opportunities where id=oid and status='published' and verification_status='verified') then raise exception 'Publication missing'; end if;
 if not exists(select 1 from public.organizations where id=(select id from admin_test_context where key='organization') and verification_status='verified') then raise exception 'Organization not verified'; end if;
 counts := public.admin_dashboard_stats();
 if (counts->>'users')::int <> (select count(*) from public.profiles) then raise exception 'Incorrect user count'; end if;
 if (counts->>'youth')::int <> (select count(*) from public.youth_profiles) then raise exception 'Incorrect youth count'; end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select id from admin_test_context where key='youth'),'role','authenticated')::text,true);
do $$ begin
 if not exists(select 1 from public.opportunities where id=(select id from admin_test_context where key='opportunity')) then raise exception 'Published opportunity absent from discovery'; end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select id from admin_test_context where key='admin'),'role','authenticated')::text,true);
do $$ declare oid uuid := (select id from admin_test_context where key='opportunity'); begin
 perform public.admin_review_opportunity(oid,'published','pause','Schedule needs confirmation');
 if (select count(*) from public.opportunity_admin_reviews where opportunity_id=oid) <> 4 then raise exception 'Decision history incomplete'; end if;
end $$;
-- Each non-admin role must fail both the public wrapper and private entry point.
do $$ declare who record; oid uuid := (select id from admin_test_context where key='opportunity'); begin
 for who in select * from admin_test_context where key in ('youth','parent','provider') loop
   perform set_config('request.jwt.claims',json_build_object('sub',who.id,'role','authenticated')::text,true);
   begin
     perform public.admin_review_opportunity(oid,'paused','requeue','');
     raise exception 'Non-admin moderation succeeded';
   exception when insufficient_privilege then null; end;
   begin
     perform private.admin_review_opportunity(oid,'paused','requeue','');
     raise exception 'Private entry point permitted non-admin';
   exception when insufficient_privilege then null; end;
   begin
     perform public.admin_dashboard_stats();
     raise exception 'Non-admin stats succeeded';
   exception when insufficient_privilege then null; end;
   if exists(select 1 from public.opportunity_admin_reviews where opportunity_id=oid) then raise exception 'History exposed'; end if;
 end loop;
 perform set_config('request.jwt.claims',json_build_object('sub',(select id from admin_test_context where key='youth'),'role','authenticated')::text,true);
 if exists(select 1 from public.opportunities where id=oid) then raise exception 'Paused opportunity remains public'; end if;
end $$;
rollback;
select 'PASS: atomic approval, rejection, requeue, pause, stale decisions, required reasons, history, stats, discovery visibility, and non-admin isolation. All fixtures rolled back.' as result;
