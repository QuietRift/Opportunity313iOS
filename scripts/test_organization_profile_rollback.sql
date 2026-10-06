begin;
create temp table org_test_context(key text primary key, id uuid);
insert into org_test_context select distinct on(role) role::text,user_id from public.user_roles where role in ('admin','parent','provider','youth') order by role,user_id;
insert into org_test_context values ('organization',gen_random_uuid()),('opportunity',gen_random_uuid()),('other',gen_random_uuid());
insert into public.organizations(id,name,organization_type,verification_status)
select id,'Rollback organization','nonprofit','pending' from org_test_context where key in ('organization','other');
insert into public.org_members(organization_id,user_id,role,status)
select (select id from org_test_context where key='organization'),id,'Provider manager','active' from org_test_context where key='provider';
grant select on org_test_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',(select id from org_test_context where key='provider'),'role','authenticated')::text,true);
do $$ declare org uuid := (select id from org_test_context where key='organization'); row public.organizations;
 payload jsonb := '{"name":"Updated Organization","organization_type":"school","description":"Serving Detroit","website":"https://example.org","contact_name":"Contact","contact_email":"contact@example.org","contact_phone":"313-555-0100","service_area":"East Side","address":"100 Test Street","city":"Detroit","verification_status":"verified"}';
begin
 row := public.save_organization_profile(org,payload);
 if row.name <> 'Updated Organization' or row.city <> 'Detroit' or row.service_area <> 'East Side' or row.contact_email <> 'contact@example.org' or row.verification_status <> 'pending' then raise exception 'Profile roundtrip failed'; end if;
 row := public.save_organization_profile(org,payload || '{"contact_email":"","city":""}'::jsonb);
 if row.contact_email is not null or row.city is not null then raise exception 'Clearing optional values failed'; end if;
 begin
  perform public.save_organization_profile((select id from org_test_context where key='other'),payload);
  raise exception 'Cross-organization edit succeeded';
 exception when insufficient_privilege then null; end;
 begin
  update public.organizations set verification_status='verified' where id=org;
  raise exception 'Self verification succeeded';
 exception when insufficient_privilege then null; end;
 begin
  update public.organizations set id=gen_random_uuid() where id=org;
  raise exception 'Identity modification succeeded';
 exception when insufficient_privilege then null; end;
 insert into public.opportunities(id,organization_id,title,summary,category,opportunity_type,starts_at,cost_cents,is_free,location_name,registration_method,status,created_by)
 values ((select id from org_test_context where key='opportunity'),org,'Rollback submission','Review required','Technology','Workshop',now()+interval '7 days',0,true,'Detroit','provider_submission','pending_review',auth.uid());
 begin
  update public.opportunities set status='published' where id=(select id from org_test_context where key='opportunity');
  raise exception 'Direct publication succeeded';
 exception when insufficient_privilege then null; end;
 begin
  perform public.publish_opportunity((select id from org_test_context where key='opportunity'));
  raise exception 'Publish RPC accepted provider';
 exception when others then if SQLERRM not like '%Admin%' and SQLERRM not like '%admin%' then raise; end if; end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select id from org_test_context where key='youth'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.opportunities where id=(select id from org_test_context where key='opportunity')) then raise exception 'Pending submission is public'; end if;
 begin
  perform public.save_organization_profile((select id from org_test_context where key='organization'),'{"name":"Unauthorized","organization_type":"school"}');
  raise exception 'Youth edit succeeded';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',(select id from org_test_context where key='admin'),'role','authenticated')::text,true);
select public.admin_review_opportunity((select id from org_test_context where key='opportunity'),'pending_review','approve','Rollback test');
select set_config('request.jwt.claims',json_build_object('sub',(select id from org_test_context where key='youth'),'role','authenticated')::text,true);
do $$ begin
 if not exists(select 1 from public.opportunities where id=(select id from org_test_context where key='opportunity') and status='published') then raise exception 'Admin-approved submission not public'; end if;
end $$;
-- Exercise first-time registration and duplicate retry protection without retaining writes.
select set_config('request.jwt.claims',json_build_object('sub',(select id from org_test_context where key='parent'),'role','authenticated')::text,true);
select public.claim_onboarding_role('provider');
do $$ declare row public.organizations; begin
 row := public.save_organization_profile(null,'{"name":"New Rollback Organization","organization_type":"nonprofit","city":"Detroit"}');
 if row.city <> 'Detroit' or row.verification_status <> 'pending' then raise exception 'Registration failed'; end if;
 if not exists(select 1 from public.org_members where organization_id=row.id and user_id=auth.uid()) then raise exception 'Membership missing'; end if;
 begin
  perform public.save_organization_profile(null,'{"name":"Duplicate Organization","organization_type":"nonprofit"}');
  raise exception 'Duplicate registration succeeded';
 exception when others then if SQLERRM not like 'An organization already exists%' then raise; end if; end;
end $$;
rollback;
select 'PASS: profile create/edit/clear, membership, duplicate prevention, ownership isolation, verification protection, pending privacy, direct publication denied, admin publication. All writes rolled back.' as result;
