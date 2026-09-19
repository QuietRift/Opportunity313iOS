-- School staff controls and a five-minute checkout over the existing ticket tables.
create function private.can_manage_school_ticketing(target_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and (
  public.has_role(auth.uid(), 'admin') or
  (public.has_role(auth.uid(), 'athletics') and exists (
   select 1 from public.events e join public.athletics_memberships am
    on am.organization_id=e.host_organization_id and am.school_id=e.school_id
   where e.id=target_event_id and e.school_id is not null and am.user_id=auth.uid()
    and am.status='active' and am.role='school_admin'
  ))
 )
$$;
revoke all on function private.can_manage_school_ticketing(uuid) from public,anon;
grant execute on function private.can_manage_school_ticketing(uuid) to authenticated;

create or replace function private.native_ticket_events(managed_only boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(data order by starts_at) from (
  select e.starts_at,jsonb_build_object('id',e.id,'title',e.title,'sport',e.sport,'starts_at',e.starts_at,'timezone',e.timezone,
  'sales_open_at',e.sales_open_at,'sales_close_at',e.sales_close_at,'event_status',e.event_status,'is_demo',e.is_demo,
  'venue_name',v.name,'school_name',s.name,'school_id',e.school_id,'venue_id',v.id,'venue_physical_capacity',v.physical_capacity,'operational_capacity',e.operational_capacity,'can_manage_capacity',private.can_manage_school_ticketing(e.id),'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),'can_manage',public.manages_event(e.id),
  'allocations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'limit_per_user',a.purchase_limit_per_user,
    'capacity',a.capacity,'remaining',greatest(0,a.capacity-(select count(*) from public.tickets t where t.allocation_id=a.id and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.status='active' and h.expires_at>now())),
    'my_remaining',greatest(0,a.purchase_limit_per_user-(select count(*) from public.tickets t where t.allocation_id=a.id and t.claimed_by=auth.uid() and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.user_id=auth.uid() and h.status='active' and h.expires_at>now()))
    ) order by a.name) from public.ticket_allocations a where a.event_id=e.id and a.active),'[]'::jsonb)) as data
  from public.events e join public.venues v on v.id=e.venue_id left join public.schools s on s.id=e.school_id
  where (managed_only and public.manages_event(e.id)) or (not managed_only and e.event_status in ('published','on_sale','sold_out') and e.starts_at>now())
 ) q),'[]'::jsonb);
end $$;

create function private.native_update_seat_limits(event_id_input uuid, venue_capacity_input integer, event_capacity_input integer, reason_input text)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.events%rowtype; v public.venues%rowtype; allocated integer; other_max integer;
begin
 if not private.can_manage_school_ticketing(event_id_input) then raise exception 'School ticket admin access required'; end if;
 if venue_capacity_input is null or venue_capacity_input<1 or event_capacity_input is null or event_capacity_input<1 or event_capacity_input>venue_capacity_input then raise exception 'Seat limits must be positive and the event cannot exceed the venue'; end if;
 if length(trim(coalesce(reason_input,'')))<3 then raise exception 'Enter a reason for this capacity change'; end if;
 select ev.* into e from public.events ev where ev.id=event_id_input;
 if e.id is null then raise exception 'Event unavailable'; end if;
 select * into v from public.venues where id=e.venue_id for update;
 select * into e from public.events where id=event_id_input for update;
 if v.physical_capacity<>venue_capacity_input and not public.has_role(auth.uid(),'admin') and exists (
  select 1 from public.events shared where shared.venue_id=v.id and (shared.school_id is distinct from e.school_id or shared.host_organization_id<>e.host_organization_id)
 ) then raise exception 'This venue serves multiple schools; a platform admin must change its physical seats'; end if;
 select coalesce(sum(capacity),0) into allocated from public.ticket_allocations where event_id=e.id and active;
 if event_capacity_input<allocated then raise exception 'Reduce student and guest allocations before lowering the event limit'; end if;
 select coalesce(max(operational_capacity),0) into other_max from public.events where venue_id=v.id and id<>e.id;
 if venue_capacity_input<other_max then raise exception 'The venue limit is below another scheduled event'; end if;
 if venue_capacity_input>v.physical_capacity then update public.venues set physical_capacity=venue_capacity_input,updated_at=now() where id=v.id; end if;
 update public.events set operational_capacity=event_capacity_input,updated_at=now() where id=e.id;
 if venue_capacity_input<v.physical_capacity then update public.venues set physical_capacity=venue_capacity_input,updated_at=now() where id=v.id; end if;
 insert into public.capacity_audit(event_id,actor,change_type,before_snapshot,after_snapshot,reason)
 values(e.id,auth.uid(),'seat_limits_changed',jsonb_build_object('venue',v.physical_capacity,'event',e.operational_capacity),
 jsonb_build_object('venue',venue_capacity_input,'event',event_capacity_input),trim(reason_input));
end $$;
create function public.native_update_seat_limits(event_id_input uuid, venue_capacity_input integer, event_capacity_input integer, reason_input text)
returns void language sql security invoker set search_path = '' as $$ select private.native_update_seat_limits(event_id_input,venue_capacity_input,event_capacity_input,reason_input) $$;

-- The older adjustment RPC allowed any event staff to change inventory. School admins now own this action.
alter function public.adjust_allocation(uuid,integer,text) set schema private;
revoke all on function private.adjust_allocation(uuid,integer,text) from public,anon,authenticated;
create function private.native_update_ticket_allocation(allocation_id_input uuid, capacity_input integer, reason_input text)
returns void language plpgsql security definer set search_path = '' as $$
declare event_id_value uuid;
begin
 select event_id into event_id_value from public.ticket_allocations where id=allocation_id_input;
 if not private.can_manage_school_ticketing(event_id_value) then raise exception 'School ticket admin access required'; end if;
 perform private.adjust_allocation(allocation_id_input,capacity_input,reason_input);
end $$;
create function public.native_update_ticket_allocation(allocation_id_input uuid, capacity_input integer, reason_input text)
returns void language sql security invoker set search_path = '' as $$ select private.native_update_ticket_allocation(allocation_id_input,capacity_input,reason_input) $$;

create function private.native_set_ticket_sales(event_id_input uuid, open_input boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.events%rowtype; total integer;
begin
 if not private.can_manage_school_ticketing(event_id_input) then raise exception 'School ticket admin access required'; end if;
 select * into e from public.events where id=event_id_input for update;
 if e.id is null or e.event_status in ('draft','cancelled','completed') then raise exception 'This event cannot change ticket sales'; end if;
 if open_input then
  if now()<e.sales_open_at or now()>=e.sales_close_at or now()>=e.starts_at then raise exception 'Ticket sales are outside the event sales window'; end if;
  select coalesce(sum(capacity),0) into total from public.ticket_allocations where event_id=e.id and active;
  if total<1 then raise exception 'Add available ticket allocations before opening sales'; end if;
 end if;
 update public.events set event_status=case when open_input then 'on_sale'::public.event_status else 'paused'::public.event_status end,updated_at=now() where id=e.id;
end $$;
create function public.native_set_ticket_sales(event_id_input uuid, open_input boolean)
returns void language sql security invoker set search_path = '' as $$ select private.native_set_ticket_sales(event_id_input,open_input) $$;

create function private.native_release_ticket_hold(hold_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare h public.ticket_holds%rowtype; eid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select a.event_id into eid from public.ticket_holds th join public.ticket_allocations a on a.id=th.allocation_id where th.id=hold_id_input and th.user_id=auth.uid();
 if eid is null then raise exception 'Hold unavailable'; end if;
 perform 1 from public.events where id=eid for update;
 select * into h from public.ticket_holds where id=hold_id_input for update;
 if h.user_id<>auth.uid() then raise exception 'Hold unavailable'; end if;
 if h.status='active' then update public.ticket_holds set status='released',updated_at=now() where id=h.id; end if;
end $$;
create function public.native_release_ticket_hold(hold_id_input uuid)
returns void language sql security invoker set search_path = '' as $$ select private.native_release_ticket_hold(hold_id_input) $$;

create function private.native_school_catalog()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if not public.has_role(auth.uid(),'admin') then raise exception 'Platform admin access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'district',s.district) order by s.name) from public.schools s),'[]'::jsonb);
end $$;
create function public.native_school_catalog()
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_school_catalog() $$;

create function private.native_assign_school_ticket_admin(school_id_input uuid, email_input text)
returns void language plpgsql security definer set search_path = '' as $$
declare sid uuid; org_id uuid; target_id uuid;
begin
 if not public.has_role(auth.uid(),'admin') then raise exception 'Platform admin access required'; end if;
 if length(trim(coalesce(email_input,'')))>254 or position('@' in coalesce(email_input,''))<2 then raise exception 'Enter a valid staff email'; end if;
 select id,organization_id into sid,org_id from public.schools where id=school_id_input;
 if sid is null then raise exception 'School unavailable'; end if;
 select id into target_id from auth.users where lower(email)=lower(trim(email_input)) and email_confirmed_at is not null;
 if target_id is null then raise exception 'This staff member needs a confirmed Opportunity313 account'; end if;
 if exists(select 1 from public.user_roles where user_id=target_id and role<>'athletics') then raise exception 'Use a separate staff account for school ticket access'; end if;
 insert into public.user_roles(user_id,role,assigned_by) values(target_id,'athletics',auth.uid()) on conflict do nothing;
 insert into public.athletics_memberships(user_id,organization_id,school_id,role,status)
 values(target_id,org_id,sid,'school_admin','active')
 on conflict(user_id,organization_id,school_id) do update set role='school_admin',status='active';
end $$;
create function public.native_assign_school_ticket_admin(school_id_input uuid,email_input text)
returns void language sql security invoker set search_path = '' as $$ select private.native_assign_school_ticket_admin(school_id_input,email_input) $$;

create function private.native_school_ticket_admins()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if not public.has_role(auth.uid(),'admin') then raise exception 'Platform admin access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',am.id,'school_id',am.school_id,'email',u.email,'status',am.status) order by u.email)
 from public.athletics_memberships am join auth.users u on u.id=am.user_id where am.role='school_admin' and am.school_id is not null and am.status='active'),'[]'::jsonb);
end $$;
create function public.native_school_ticket_admins()
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_school_ticket_admins() $$;

create function private.native_revoke_school_ticket_admin(membership_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.has_role(auth.uid(),'admin') then raise exception 'Platform admin access required'; end if;
 update public.athletics_memberships set status='revoked' where id=membership_id_input and role='school_admin';
 if not found then raise exception 'School staff assignment unavailable'; end if;
end $$;
create function public.native_revoke_school_ticket_admin(membership_id_input uuid)
returns void language sql security invoker set search_path = '' as $$ select private.native_revoke_school_ticket_admin(membership_id_input) $$;

alter table public.ticket_scans add column if not exists id_checked boolean not null default false;
create function private.native_staff_check_in(presented_token text,requested_event_id uuid,id_checked_input boolean)
returns table(matched_ticket_id uuid,result public.scan_result) language plpgsql security definer set search_path = '' as $$
declare allocation_name text; row_result record;
begin
 if auth.uid() is null or not public.manages_event(requested_event_id) then raise exception 'Event staff access required'; end if;
 if length(coalesce(presented_token,''))<>64 then raise exception 'Enter a valid ticket code'; end if;
 select a.name into allocation_name from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id
 where a.event_id=requested_event_id and t.token_hash=encode(extensions.digest(presented_token,'sha256'),'hex');
 if allocation_name is not null and lower(allocation_name) like 'student%' and not coalesce(id_checked_input,false) then
  raise exception 'Visually check the student ID before admitting this ticket';
 end if;
 for row_result in select * from private.native_scan_ticket(presented_token,requested_event_id) loop
  matched_ticket_id:=row_result.matched_ticket_id; result:=row_result.result;
  if result='accepted' and lower(coalesce(allocation_name,'')) like 'student%' then
   update public.ticket_scans set id_checked=true where id=(select id from public.ticket_scans where ticket_id=matched_ticket_id and result='accepted' order by scanned_at desc limit 1);
  end if;
  return next;
 end loop;
end $$;
create function public.native_staff_check_in(presented_token text,requested_event_id uuid,id_checked_input boolean)
returns table(matched_ticket_id uuid,result public.scan_result) language sql security invoker set search_path = '' as $$ select * from private.native_staff_check_in(presented_token,requested_event_id,id_checked_input) $$;
revoke execute on function public.scan_ticket(text,uuid) from authenticated;

-- All new endpoints are authenticated; private functions are reached only through guarded wrappers.
revoke all on function private.native_update_seat_limits(uuid,integer,integer,text) from public,anon;
grant execute on function private.native_update_seat_limits(uuid,integer,integer,text) to authenticated;
revoke all on function public.native_update_seat_limits(uuid,integer,integer,text) from public,anon;
grant execute on function public.native_update_seat_limits(uuid,integer,integer,text) to authenticated;
revoke all on function private.native_update_ticket_allocation(uuid,integer,text) from public,anon;
grant execute on function private.native_update_ticket_allocation(uuid,integer,text) to authenticated;
revoke all on function public.native_update_ticket_allocation(uuid,integer,text) from public,anon;
grant execute on function public.native_update_ticket_allocation(uuid,integer,text) to authenticated;
revoke all on function private.native_set_ticket_sales(uuid,boolean) from public,anon;
grant execute on function private.native_set_ticket_sales(uuid,boolean) to authenticated;
revoke all on function public.native_set_ticket_sales(uuid,boolean) from public,anon;
grant execute on function public.native_set_ticket_sales(uuid,boolean) to authenticated;
revoke all on function private.native_release_ticket_hold(uuid) from public,anon;
grant execute on function private.native_release_ticket_hold(uuid) to authenticated;
revoke all on function public.native_release_ticket_hold(uuid) from public,anon;
grant execute on function public.native_release_ticket_hold(uuid) to authenticated;
revoke all on function private.native_school_catalog() from public,anon;
grant execute on function private.native_school_catalog() to authenticated;
revoke all on function public.native_school_catalog() from public,anon;
grant execute on function public.native_school_catalog() to authenticated;
revoke all on function private.native_assign_school_ticket_admin(uuid,text) from public,anon;
grant execute on function private.native_assign_school_ticket_admin(uuid,text) to authenticated;
revoke all on function public.native_assign_school_ticket_admin(uuid,text) from public,anon;
grant execute on function public.native_assign_school_ticket_admin(uuid,text) to authenticated;
revoke all on function private.native_school_ticket_admins() from public,anon;
grant execute on function private.native_school_ticket_admins() to authenticated;
revoke all on function public.native_school_ticket_admins() from public,anon;
grant execute on function public.native_school_ticket_admins() to authenticated;
revoke all on function private.native_revoke_school_ticket_admin(uuid) from public,anon;
grant execute on function private.native_revoke_school_ticket_admin(uuid) to authenticated;
revoke all on function public.native_revoke_school_ticket_admin(uuid) from public,anon;
grant execute on function public.native_revoke_school_ticket_admin(uuid) to authenticated;
revoke all on function private.native_staff_check_in(text,uuid,boolean) from public,anon;
grant execute on function private.native_staff_check_in(text,uuid,boolean) to authenticated;
revoke all on function public.native_staff_check_in(text,uuid,boolean) from public,anon;
grant execute on function public.native_staff_check_in(text,uuid,boolean) to authenticated;
