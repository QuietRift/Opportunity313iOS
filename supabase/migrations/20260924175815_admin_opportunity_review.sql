-- Rejections use existing closed + rejected values, preserving public discovery queries.
create table public.opportunity_admin_reviews (
 id uuid primary key default gen_random_uuid(),
 opportunity_id uuid not null references public.opportunities(id) on delete cascade,
 reviewer_id uuid references auth.users(id) on delete set null,
 action text not null check (action in ('approve','reject','pause','requeue')),
 previous_status text not null,
 resulting_status text not null,
 reason text check (char_length(reason) <= 2000),
 created_at timestamptz not null default now()
);
alter table public.opportunity_admin_reviews enable row level security;
create policy admin_review_history_select on public.opportunity_admin_reviews
 for select to authenticated using (public.has_role((select auth.uid()), 'admin'));
grant select on public.opportunity_admin_reviews to authenticated;
revoke all on public.opportunity_admin_reviews from anon;
create index opportunity_admin_reviews_opportunity_date on public.opportunity_admin_reviews(opportunity_id,created_at desc);
create index opportunity_admin_reviews_reviewer on public.opportunity_admin_reviews(reviewer_id);

-- Privileged transaction stays outside the exposed schema, with explicit authorization.
create or replace function private.admin_review_opportunity(
 target_opportunity_id uuid, expected_status text, decision text, review_reason text default ''
) returns public.opportunities language plpgsql security definer set search_path = '' as $$
declare
 current_row public.opportunities;
 updated_row public.opportunities;
 clean_reason text := nullif(btrim(review_reason), '');
begin
 if auth.uid() is null or not public.has_role(auth.uid(), 'admin') then
   raise exception 'Admin role required' using errcode = '42501';
 end if;
 select * into current_row from public.opportunities where id=target_opportunity_id for update;
 if not found then raise exception 'Opportunity no longer exists'; end if;
 if current_row.status::text is distinct from expected_status then
   raise exception 'This opportunity changed. Refresh and review its current status.';
 end if;
 if char_length(clean_reason) > 2000 then raise exception 'Review note must be 2,000 characters or fewer'; end if;
 if decision in ('reject','pause') and clean_reason is null then raise exception 'A review reason is required'; end if;
 if decision='approve' and current_row.status='pending_review' then
   -- Both operations roll back if validation or publication fails.
   perform public.verify_provider_organization(current_row.organization_id);
   select * into updated_row from public.publish_opportunity(target_opportunity_id);
 elsif decision='reject' and current_row.status='pending_review' then
   update public.opportunities set status='closed', verification_status='rejected', published_at=null
   where id=target_opportunity_id returning * into updated_row;
 elsif decision='pause' and current_row.status='published' then
   update public.opportunities set status='paused' where id=target_opportunity_id returning * into updated_row;
 elsif decision='requeue' and (current_row.status='paused' or current_row.verification_status='rejected') then
   update public.opportunities set status='pending_review', verification_status='pending', published_at=null
   where id=target_opportunity_id returning * into updated_row;
 else
   raise exception 'This action is not allowed from the current status';
 end if;
 insert into public.opportunity_admin_reviews(opportunity_id,reviewer_id,action,previous_status,resulting_status,reason)
 values(target_opportunity_id,auth.uid(),decision,current_row.status::text,updated_row.status::text,clean_reason);
 return updated_row;
end $$;
revoke all on function private.admin_review_opportunity(uuid,text,text,text) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.admin_review_opportunity(uuid,text,text,text) to authenticated;
create or replace function public.admin_review_opportunity(
 target_opportunity_id uuid, expected_status text, decision text, review_reason text default ''
) returns public.opportunities language sql security invoker set search_path = '' as $$
 select private.admin_review_opportunity(target_opportunity_id, expected_status, decision, review_reason);
$$;
revoke all on function public.admin_review_opportunity(uuid,text,text,text) from public, anon;
grant execute on function public.admin_review_opportunity(uuid,text,text,text) to authenticated;

create or replace function public.admin_dashboard_stats() returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
begin
 if auth.uid() is null or not public.has_role(auth.uid(), 'admin') then
   raise exception 'Admin role required' using errcode='42501';
 end if;
 return jsonb_build_object(
   'pending',(select count(*) from public.opportunities where status='pending_review'),
   'approved',(select count(*) from public.opportunities where status='published'),
   'rejected',(select count(*) from public.opportunities where verification_status='rejected'),
   'paused',(select count(*) from public.opportunities where status='paused' and verification_status<>'rejected'),
   'users',(select count(*) from public.profiles),
   'youth',(select count(*) from public.youth_profiles),
   'organizations',(select count(*) from public.organizations),
   'parentManaged',(select count(*) from public.youth_profiles where account_type='parent_managed')
 );
end $$;
revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;
