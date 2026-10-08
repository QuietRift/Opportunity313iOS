create table public.issue_reports (
 id uuid primary key,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 category text not null check(category in ('app','account','registration','opportunity','other')),
 title text not null check(length(title) between 3 and 120),
 details text not null check(length(details) between 10 and 4000),
 opportunity_id uuid references public.opportunities(id) on delete set null,
 opportunity_name text,
 platform text not null check(platform in ('ios','web')),
 app_version text check(length(app_version)<=80),
 status text not null default 'submitted' check(status in ('submitted','in_review','resolved')),
 response text not null default '' check(length(response)<=2000),
 version integer not null default 1,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index issue_reports_owner_created on public.issue_reports(reporter_id,created_at desc);
create index issue_reports_status_created on public.issue_reports(status,created_at desc);
create index issue_reports_opportunity on public.issue_reports(opportunity_id);
alter table public.issue_reports enable row level security;
revoke all on public.issue_reports from anon,authenticated;
grant select on public.issue_reports to authenticated;
create policy own_issue_reports on public.issue_reports for select to authenticated
 using(reporter_id=(select auth.uid()) or public.has_role((select auth.uid()),'admin'));
create table private.issue_report_actions (
 id uuid primary key default gen_random_uuid(),report_id uuid not null references public.issue_reports(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,status text not null,response text not null,created_at timestamptz not null default now()
);
create index on private.issue_report_actions(report_id);
create index on private.issue_report_actions(actor_id);
alter table private.issue_report_actions enable row level security;
revoke all on private.issue_report_actions from public,anon,authenticated;

create function private.native_submit_issue_report(request_id_input uuid,category_input text,title_input text,details_input text,platform_input text,opportunity_id_input uuid default null,app_version_input text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); report public.issue_reports%rowtype; opportunity_name_value text;
begin
 if actor is null then raise exception 'Sign in to report an issue'; end if;
 -- Serialize per-account submissions so the limit also holds for concurrent requests.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 select * into report from public.issue_reports where id=request_id_input;
 if report.id is not null then
  if report.reporter_id<>actor then raise exception 'Invalid report request'; end if;
  return to_jsonb(report);
 end if;
 if category_input is null or category_input not in ('app','account','registration','opportunity','other') or platform_input is null or platform_input not in ('ios','web') then raise exception 'Choose a valid issue category'; end if;
 if title_input is null or length(btrim(title_input)) not between 3 and 120 then raise exception 'Enter a title between 3 and 120 characters'; end if;
 if details_input is null or length(btrim(details_input)) not between 10 and 4000 then raise exception 'Describe the issue using 10 to 4000 characters'; end if;
 if (select count(*) from public.issue_reports where reporter_id=actor and created_at>now()-interval '10 minutes')>=5 then raise exception 'You have sent several reports. Please wait a few minutes before sending another'; end if;
 if opportunity_id_input is not null then
  select o.title into opportunity_name_value from public.opportunities o where o.id=opportunity_id_input and (
   o.status='published' or public.manages_organization(o.organization_id) or
   exists(select 1 from public.opportunity_tickets t where t.opportunity_id=o.id and (t.attendee_user_id=actor or
    exists(select 1 from public.youth_profiles y where y.id=t.youth_profile_id and y.user_id=actor) or
    exists(select 1 from public.guardian_relationships g where g.youth_profile_id=t.youth_profile_id and g.guardian_user_id=actor and g.status='active')))
  );
  if opportunity_name_value is null then raise exception 'Opportunity unavailable. Submit a general report instead'; end if;
 end if;
 insert into public.issue_reports(id,reporter_id,category,title,details,opportunity_id,opportunity_name,platform,app_version)
 values(request_id_input,actor,category_input,btrim(title_input),btrim(details_input),opportunity_id_input,opportunity_name_value,platform_input,left(app_version_input,80)) returning * into report;
 return to_jsonb(report);
end $$;
create function public.native_submit_issue_report(request_id_input uuid,category_input text,title_input text,details_input text,platform_input text,opportunity_id_input uuid default null,app_version_input text default null)
returns jsonb language sql security invoker set search_path='' as $$
 select private.native_submit_issue_report(request_id_input,category_input,title_input,details_input,platform_input,opportunity_id_input,app_version_input);
$$;
revoke all on function private.native_submit_issue_report(uuid,text,text,text,text,uuid,text),public.native_submit_issue_report(uuid,text,text,text,text,uuid,text) from public,anon;
grant execute on function private.native_submit_issue_report(uuid,text,text,text,text,uuid,text),public.native_submit_issue_report(uuid,text,text,text,text,uuid,text) to authenticated;

create function private.native_review_issue_report(report_id_input uuid,status_input text,response_input text,expected_version_input integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare report public.issue_reports%rowtype;
begin
 if auth.uid() is null or not public.has_role(auth.uid(),'admin') then raise exception 'Administrator access required'; end if;
 if status_input is null or status_input not in ('submitted','in_review','resolved') then raise exception 'Choose a valid status'; end if;
 if response_input is null or length(btrim(response_input))>2000 then raise exception 'The response must be 2000 characters or fewer'; end if;
 if status_input='resolved' and length(btrim(response_input))<5 then raise exception 'Add a response explaining the resolution'; end if;
 select * into report from public.issue_reports where id=report_id_input for update;
 if report.id is null then raise exception 'Report unavailable'; end if;
 if report.status=status_input and report.response=btrim(response_input) then return to_jsonb(report); end if;
 if expected_version_input is null or report.version<>expected_version_input then raise exception 'This report changed. Refresh before saving'; end if;
 update public.issue_reports set status=status_input,response=btrim(response_input),version=version+1,updated_at=clock_timestamp() where id=report.id returning * into report;
 insert into private.issue_report_actions(report_id,actor_id,status,response) values(report.id,auth.uid(),report.status,report.response);
 return to_jsonb(report);
end $$;
create function public.native_review_issue_report(report_id_input uuid,status_input text,response_input text,expected_version_input integer)
returns jsonb language sql security invoker set search_path='' as $$
 select private.native_review_issue_report(report_id_input,status_input,response_input,expected_version_input);
$$;
revoke all on function private.native_review_issue_report(uuid,text,text,integer),public.native_review_issue_report(uuid,text,text,integer) from public,anon;
grant execute on function private.native_review_issue_report(uuid,text,text,integer),public.native_review_issue_report(uuid,text,text,integer) to authenticated;
