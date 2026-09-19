-- A student links a school to a youth profile; that school's admin verifies ID in person.
-- The app and database never upload or store an ID image.
create table public.student_school_verifications (
 id uuid primary key default extensions.gen_random_uuid(),
 youth_profile_id uuid not null unique references public.youth_profiles(id) on delete cascade,
 school_id uuid not null references public.schools(id),
 status text not null default 'pending' check (status in ('pending','verified','rejected','revoked')),
 requested_by uuid not null references auth.users(id),
 verified_by uuid references auth.users(id),
 requested_at timestamptz not null default now(),
 reviewed_at timestamptz,
 updated_at timestamptz not null default now()
);
create index student_school_verifications_school_status_idx on public.student_school_verifications(school_id,status);
alter table public.student_school_verifications enable row level security;
revoke all on public.student_school_verifications from public,anon,authenticated;

create function private.reset_school_verification_after_identity_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.first_name is distinct from old.first_name or new.grade is distinct from old.grade then
  update public.student_school_verifications set status='pending',verified_by=null,
   reviewed_at=null,requested_at=now(),updated_at=now()
   where youth_profile_id=new.id and status='verified';
 end if;
 return new;
end $$;
create trigger reset_school_verification_after_identity_change
 after update of first_name,grade on public.youth_profiles
 for each row execute function private.reset_school_verification_after_identity_change();
revoke all on function private.reset_school_verification_after_identity_change() from public,anon,authenticated;

alter table public.ticket_allocations add column eligibility_kind text not null default 'general'
 check (eligibility_kind in ('general','student'));
update public.ticket_allocations set eligibility_kind='student' where lower(name) like 'student%';
alter table public.ticket_holds add column assigned_youth_profile_id uuid references public.youth_profiles(id);
alter table public.ticket_holds add constraint student_hold_single_ticket check (assigned_youth_profile_id is null or quantity=1);

create function private.can_claim_youth_profile(profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and (
  exists(select 1 from public.youth_profiles yp where yp.id=profile_id and yp.user_id=auth.uid()) or
  exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=profile_id and gr.guardian_user_id=auth.uid() and gr.status='active')
 )
$$;
create function private.can_verify_school_students(target_school_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and public.has_role(auth.uid(),'athletics') and exists (
  select 1 from public.athletics_memberships am join public.schools s on s.id=am.school_id
   where am.user_id=auth.uid() and am.organization_id=s.organization_id
   and am.school_id=target_school_id and am.role='school_admin' and am.status='active'
 )
$$;
create function private.student_school_is_verified(profile_id uuid,target_school_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select profile_id is not null and target_school_id is not null and exists (
  select 1 from public.student_school_verifications sv
  where sv.youth_profile_id=profile_id and sv.school_id=target_school_id and sv.status='verified'
 )
$$;

create function private.native_school_profile_catalog()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'district',s.district) order by s.name)
  from public.schools s),'[]'::jsonb);
end $$;
create function public.native_school_profile_catalog()
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_school_profile_catalog() $$;

create function private.native_my_school_profiles()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'youth_profile_id',yp.id,'youth_name',yp.first_name,'grade',yp.grade,
  'verification_id',sv.id,'school_id',sv.school_id,'school_name',s.name,'status',coalesce(sv.status,'not_linked')
 ) order by yp.first_name)
 from public.youth_profiles yp
 left join public.student_school_verifications sv on sv.youth_profile_id=yp.id
 left join public.schools s on s.id=sv.school_id
 where yp.user_id=auth.uid() or exists(
  select 1 from public.guardian_relationships gr where gr.youth_profile_id=yp.id
   and gr.guardian_user_id=auth.uid() and gr.status='active'
 )),'[]'::jsonb);
end $$;
create function public.native_my_school_profiles()
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_my_school_profiles() $$;

create function private.native_request_school_verification(youth_profile_id_input uuid,school_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.can_claim_youth_profile(youth_profile_id_input) then raise exception 'Youth profile unavailable'; end if;
 if not exists(select 1 from public.schools where id=school_id_input) then raise exception 'School unavailable'; end if;
 insert into public.student_school_verifications(youth_profile_id,school_id,status,requested_by)
 values(youth_profile_id_input,school_id_input,'pending',auth.uid())
 on conflict(youth_profile_id) do update set school_id=excluded.school_id,status='pending',
  requested_by=auth.uid(),requested_at=now(),reviewed_at=null,verified_by=null,updated_at=now()
 where public.student_school_verifications.school_id is distinct from excluded.school_id
    or public.student_school_verifications.status in ('rejected','revoked');
end $$;
create function public.native_request_school_verification(youth_profile_id_input uuid,school_id_input uuid)
returns void language sql security invoker set search_path = '' as $$ select private.native_request_school_verification(youth_profile_id_input,school_id_input) $$;

create function private.native_school_verification_queue()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.has_role(auth.uid(),'athletics') then raise exception 'School staff access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',sv.id,'youth_profile_id',sv.youth_profile_id,
  'youth_name',yp.first_name,'grade',yp.grade,'school_id',s.id,'school_name',s.name,
  'status',sv.status,'requested_at',sv.requested_at) order by sv.requested_at desc)
 from public.student_school_verifications sv
 join public.youth_profiles yp on yp.id=sv.youth_profile_id
 join public.schools s on s.id=sv.school_id
 where private.can_verify_school_students(sv.school_id) and sv.status in ('pending','verified')),'[]'::jsonb);
end $$;
create function public.native_school_verification_queue()
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_school_verification_queue() $$;

create function private.native_review_school_verification(verification_id_input uuid,approve_input boolean,id_checked_input boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare request_row public.student_school_verifications%rowtype;
begin
 select * into request_row from public.student_school_verifications where id=verification_id_input for update;
 if request_row.id is null or not private.can_verify_school_students(request_row.school_id) then
  raise exception 'School verification request unavailable';
 end if;
 if approve_input and not coalesce(id_checked_input,false) then raise exception 'Check the school ID in person before approval'; end if;
 if approve_input and request_row.status<>'pending' then raise exception 'Only pending requests can be approved'; end if;
 if not approve_input and request_row.status not in ('pending','verified') then raise exception 'This request is already closed'; end if;
 update public.student_school_verifications set
  status=case when approve_input then 'verified' when request_row.status='verified' then 'revoked' else 'rejected' end,
  verified_by=auth.uid(),reviewed_at=now(),updated_at=now() where id=request_row.id;
end $$;
create function public.native_review_school_verification(verification_id_input uuid,approve_input boolean,id_checked_input boolean)
returns void language sql security invoker set search_path = '' as $$ select private.native_review_school_verification(verification_id_input,approve_input,id_checked_input) $$;

-- The old direct hold function has no student identity, so only the guarded wrapper is exposed.
revoke all on function public.create_ticket_hold(uuid,integer,text) from public,anon,authenticated;
revoke all on function private.native_reserve_tickets(uuid,integer,text) from public,anon,authenticated;

create function private.native_create_ticket_hold(requested_allocation_id uuid,requested_quantity integer,requested_idempotency_key text,youth_profile_id_input uuid default null)
returns public.ticket_holds language plpgsql security definer set search_path = '' as $$
declare allocation_row public.ticket_allocations%rowtype; event_row public.events%rowtype; h public.ticket_holds%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select a.* into allocation_row from public.ticket_allocations a where a.id=requested_allocation_id;
 if allocation_row.id is null then raise exception 'Ticket option unavailable'; end if;
 select * into event_row from public.events where id=allocation_row.event_id for update;
 if allocation_row.eligibility_kind='student' then
  if requested_quantity<>1 or youth_profile_id_input is null then raise exception 'Select one verified student for this ticket'; end if;
  if not private.can_claim_youth_profile(youth_profile_id_input)
    or not private.student_school_is_verified(youth_profile_id_input,event_row.school_id) then
   raise exception 'This student is not verified for the event school';
  end if;
  if exists(select 1 from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id
   where a.event_id=event_row.id and t.assigned_youth_profile_id=youth_profile_id_input and t.status in ('issued','scanned'))
   or exists(select 1 from public.ticket_holds th join public.ticket_allocations a on a.id=th.allocation_id
   where a.event_id=event_row.id and th.assigned_youth_profile_id=youth_profile_id_input
    and th.status='active' and th.expires_at>now() and th.idempotency_key<>requested_idempotency_key)
  then raise exception 'This student already has a ticket or active hold for this event'; end if;
 elsif youth_profile_id_input is not null then
  raise exception 'Only student tickets can be assigned to a youth profile';
 end if;
 h := public.create_ticket_hold(requested_allocation_id,requested_quantity,requested_idempotency_key);
 if allocation_row.eligibility_kind='student' then
  if h.assigned_youth_profile_id is not null and h.assigned_youth_profile_id<>youth_profile_id_input then
   raise exception 'This checkout belongs to a different student';
  end if;
  if h.status='active' and h.assigned_youth_profile_id is null then
   update public.ticket_holds set assigned_youth_profile_id=youth_profile_id_input,updated_at=now() where id=h.id returning * into h;
  end if;
 end if;
 return h;
end $$;
create function public.native_create_ticket_hold(requested_allocation_id uuid,requested_quantity integer,requested_idempotency_key text,youth_profile_id_input uuid default null)
returns public.ticket_holds language sql security invoker set search_path = '' as $$
 select private.native_create_ticket_hold(requested_allocation_id,requested_quantity,requested_idempotency_key,youth_profile_id_input)
$$;

-- Preserve the proven inventory/expiry logic while assigning and rechecking the student.
alter function private.issue_ticket(uuid) rename to legacy_issue_ticket;
revoke all on function private.legacy_issue_ticket(uuid) from public,anon,authenticated;
create function private.issue_ticket(requested_hold_id uuid)
returns table(ticket_id uuid,token text) language plpgsql security definer set search_path = '' as $$
declare h public.ticket_holds%rowtype; a public.ticket_allocations%rowtype; e public.events%rowtype; issued record;
begin
 select * into h from public.ticket_holds where id=requested_hold_id and user_id=auth.uid();
 if h.id is null then raise exception 'Hold unavailable'; end if;
 select * into a from public.ticket_allocations where id=h.allocation_id;
 select * into e from public.events where id=a.event_id for update;
 if a.eligibility_kind='student' then
  if h.quantity<>1 or h.assigned_youth_profile_id is null
   or not private.can_claim_youth_profile(h.assigned_youth_profile_id)
   or not private.student_school_is_verified(h.assigned_youth_profile_id,e.school_id) then
   raise exception 'Student school verification is required for this event';
  end if;
  if exists(select 1 from public.tickets t join public.ticket_allocations ta on ta.id=t.allocation_id
   where ta.event_id=e.id and t.assigned_youth_profile_id=h.assigned_youth_profile_id and t.status in ('issued','scanned')) then
   raise exception 'This student already has a ticket for this event';
  end if;
 end if;
 for issued in select * from private.legacy_issue_ticket(requested_hold_id) loop
  if a.eligibility_kind='student' then
   update public.tickets set assigned_youth_profile_id=h.assigned_youth_profile_id where id=issued.ticket_id;
  end if;
  ticket_id:=issued.ticket_id; token:=issued.token; return next;
 end loop;
end $$;
create or replace function public.issue_ticket(requested_hold_id uuid)
returns table(ticket_id uuid,token text) language sql security invoker set search_path = '' as $$ select * from private.issue_ticket(requested_hold_id) $$;

create or replace function private.native_staff_check_in(presented_token text,requested_event_id uuid,id_checked_input boolean)
returns table(matched_ticket_id uuid,result public.scan_result) language plpgsql security definer set search_path = '' as $$
declare kind text; student_id uuid; school_id_value uuid; row_result record;
begin
 if auth.uid() is null or not public.manages_event(requested_event_id) then raise exception 'Event staff access required'; end if;
 if length(coalesce(presented_token,''))<>64 then raise exception 'Enter a valid ticket code'; end if;
 select a.eligibility_kind,t.assigned_youth_profile_id,e.school_id into kind,student_id,school_id_value
 from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id
 join public.events e on e.id=a.event_id
 where e.id=requested_event_id and t.token_hash=encode(extensions.digest(presented_token,'sha256'),'hex');
 if kind='student' and not private.student_school_is_verified(student_id,school_id_value) then
  raise exception 'Student school verification is unavailable; do not admit on this ticket';
 end if;
 for row_result in select * from private.native_scan_ticket(presented_token,requested_event_id) loop
  matched_ticket_id:=row_result.matched_ticket_id; result:=row_result.result; return next;
 end loop;
end $$;

-- Both profile and ticket RPCs return only the minimum data needed by their callers.
create or replace function private.native_ticket_events(managed_only boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(data order by starts_at) from (
  select e.starts_at,jsonb_build_object('id',e.id,'title',e.title,'sport',e.sport,'starts_at',e.starts_at,'timezone',e.timezone,
  'sales_open_at',e.sales_open_at,'sales_close_at',e.sales_close_at,'event_status',e.event_status,'is_demo',e.is_demo,
  'venue_name',v.name,'school_name',s.name,'school_id',e.school_id,'venue_id',v.id,'venue_physical_capacity',v.physical_capacity,'operational_capacity',e.operational_capacity,'can_manage_capacity',private.can_manage_school_ticketing(e.id),'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),'can_manage',public.manages_event(e.id),
  'allocations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'limit_per_user',a.purchase_limit_per_user,
    'eligibility_kind',a.eligibility_kind,'capacity',a.capacity,
    'remaining',greatest(0,a.capacity-(select count(*) from public.tickets t where t.allocation_id=a.id and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.status='active' and h.expires_at>now())),
    'my_remaining',greatest(0,a.purchase_limit_per_user-(select count(*) from public.tickets t where t.allocation_id=a.id and t.claimed_by=auth.uid() and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.user_id=auth.uid() and h.status='active' and h.expires_at>now()))
    ) order by a.name) from public.ticket_allocations a where a.event_id=e.id and a.active),'[]'::jsonb)) as data
  from public.events e join public.venues v on v.id=e.venue_id left join public.schools s on s.id=e.school_id
  where (managed_only and public.manages_event(e.id)) or (not managed_only and e.event_status in ('published','on_sale','sold_out') and e.starts_at>now())
 ) q),'[]'::jsonb);
end $$;

create or replace function private.native_ticket_wallet(event_id_input uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if event_id_input is not null and not public.manages_event(event_id_input) then raise exception 'Event staff access required'; end if;
 return coalesce((select jsonb_agg(data order by issued_at desc) from (
  select t.issued_at,jsonb_build_object('id',t.id,'event_id',e.id,'event_title',e.title,'allocation_name',a.name,
   'assigned_youth_name',yp.first_name,'starts_at',e.starts_at,'timezone',e.timezone,'venue_name',v.name,
   'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),
   'status',t.status,'event_status',e.event_status,'is_demo',e.is_demo,'issued_at',t.issued_at) data
  from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id
  join public.events e on e.id=a.event_id join public.venues v on v.id=e.venue_id
  left join public.youth_profiles yp on yp.id=t.assigned_youth_profile_id
  where (event_id_input is null and t.claimed_by=auth.uid()) or (event_id_input is not null and e.id=event_id_input)
 ) q),'[]'::jsonb);
end $$;

-- Private implementations are not an exposed API. Public wrappers are authenticated only.
revoke all on function private.can_claim_youth_profile(uuid),private.can_verify_school_students(uuid),private.student_school_is_verified(uuid,uuid) from public,anon,authenticated;
revoke all on function private.native_school_profile_catalog(),private.native_my_school_profiles(),private.native_request_school_verification(uuid,uuid),private.native_school_verification_queue(),private.native_review_school_verification(uuid,boolean,boolean),private.native_create_ticket_hold(uuid,integer,text,uuid) from public,anon;
grant execute on function private.native_school_profile_catalog(),private.native_my_school_profiles(),private.native_request_school_verification(uuid,uuid),private.native_school_verification_queue(),private.native_review_school_verification(uuid,boolean,boolean),private.native_create_ticket_hold(uuid,integer,text,uuid) to authenticated;
revoke all on function public.native_school_profile_catalog(),public.native_my_school_profiles(),public.native_request_school_verification(uuid,uuid),public.native_school_verification_queue(),public.native_review_school_verification(uuid,boolean,boolean),public.native_create_ticket_hold(uuid,integer,text,uuid) from public,anon;
grant execute on function public.native_school_profile_catalog(),public.native_my_school_profiles(),public.native_request_school_verification(uuid,uuid),public.native_school_verification_queue(),public.native_review_school_verification(uuid,boolean,boolean),public.native_create_ticket_hold(uuid,integer,text,uuid) to authenticated;
revoke all on function private.issue_ticket(uuid) from public,anon;
grant execute on function private.issue_ticket(uuid) to authenticated;
