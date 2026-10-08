alter table public.opportunity_tickets
 add column cancelled_at timestamptz,
 add column cancelled_by uuid references auth.users(id) on delete set null,
 add column attended_at timestamptz,
 add column attended_by uuid references auth.users(id) on delete set null;
create index opportunity_tickets_cancelled_by_idx on public.opportunity_tickets(cancelled_by) where cancelled_by is not null;
create index opportunity_tickets_attended_by_idx on public.opportunity_tickets(attended_by) where attended_by is not null;

-- Managed children can read their registrations but cannot cancel them.
create function private.can_manage_opportunity_registration(registration_id_input uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
  select 1 from public.opportunity_tickets t where t.id=registration_id_input and (
   t.attendee_user_id=auth.uid() or
   exists(select 1 from public.youth_profiles yp where yp.id=t.youth_profile_id and yp.user_id=auth.uid() and yp.account_type='youth_account') or
   (public.has_role(auth.uid(),'parent') and exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=t.youth_profile_id and gr.guardian_user_id=auth.uid() and gr.status='active'))
  )
 );
$$;

create function public.native_my_registrations()
returns jsonb language sql stable security invoker set search_path = '' as $$
 select coalesce(jsonb_agg(to_jsonb(t) || jsonb_build_object('can_cancel',
  private.can_manage_opportunity_registration(t.id) and t.status='upcoming' and (t.starts_at is null or t.starts_at>now())
 ) order by t.created_at desc),'[]'::jsonb) from public.opportunity_tickets t;
$$;

create function private.native_cancel_opportunity_registration(registration_id_input uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t public.opportunity_tickets%rowtype;
begin
 if not private.can_manage_opportunity_registration(registration_id_input) then raise exception 'You cannot cancel this registration'; end if;
 -- Share the issuance lock order: opportunity first, then registration.
 perform 1 from public.opportunities o join public.opportunity_tickets tk on tk.opportunity_id=o.id where tk.id=registration_id_input for update of o;
 select * into t from public.opportunity_tickets where id=registration_id_input for update;
 if not private.can_manage_opportunity_registration(t.id) then raise exception 'You cannot cancel this registration'; end if;
 if t.status='cancelled' then return to_jsonb(t) || jsonb_build_object('can_cancel',false); end if;
 if t.status<>'upcoming' then raise exception 'An attended or expired registration cannot be cancelled'; end if;
 if t.starts_at is not null and t.starts_at<=now() then raise exception 'Cancellation closes when the opportunity starts'; end if;
 update public.opportunity_tickets set status='cancelled',cancelled_at=now(),cancelled_by=auth.uid() where id=t.id returning * into t;
 return to_jsonb(t) || jsonb_build_object('can_cancel',false);
end $$;
create function public.native_cancel_opportunity_registration(registration_id_input uuid)
returns jsonb language sql security invoker set search_path = '' as $$
 select private.native_cancel_opportunity_registration(registration_id_input);
$$;

-- A roster is a restricted projection: providers receive no QR entry codes,
-- auth user IDs, family relationships, or child contact information.
create function private.native_opportunity_attendees(opportunity_id_input uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare o public.opportunities%rowtype; reserved bigint;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into o from public.opportunities where id=opportunity_id_input;
 if o.id is null or not public.manages_organization(o.organization_id) then raise exception 'Organization access required'; end if;
 select count(*) into reserved from public.opportunity_tickets where opportunity_id=o.id and status<>'cancelled';
 return jsonb_build_object('opportunity_id',o.id,'capacity',o.capacity,'registered_count',reserved,
  'remaining',case when o.capacity is null then null else greatest(0,o.capacity-reserved) end,
  'attended_count',(select count(*) from public.opportunity_tickets where opportunity_id=o.id and status='used'),
  'cancelled_count',(select count(*) from public.opportunity_tickets where opportunity_id=o.id and status='cancelled'),
  'attendees',coalesce((select jsonb_agg(jsonb_build_object(
   'id',t.id,'attendee_name',t.attendee_name,'status',t.status,'registered_at',t.created_at,'attended_at',t.attended_at,'cancelled_at',t.cancelled_at
  ) order by t.created_at,t.id) from public.opportunity_tickets t where t.opportunity_id=o.id),'[]'::jsonb));
end $$;
create function public.native_opportunity_attendees(opportunity_id_input uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
 select private.native_opportunity_attendees(opportunity_id_input);
$$;

create function private.native_mark_opportunity_attendance(registration_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare t public.opportunity_tickets%rowtype; organization_id_found uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select o.organization_id into organization_id_found from public.opportunities o join public.opportunity_tickets tk on tk.opportunity_id=o.id where tk.id=registration_id_input for update of o;
 if organization_id_found is null or not public.manages_organization(organization_id_found) then raise exception 'Organization access required'; end if;
 select * into t from public.opportunity_tickets where id=registration_id_input for update;
 if t.status='used' then return; end if;
 if t.status<>'upcoming' then raise exception 'Only a confirmed registration can be marked attended'; end if;
 update public.opportunity_tickets set status='used',attended_at=now(),attended_by=auth.uid() where id=t.id;
end $$;
create function public.native_mark_opportunity_attendance(registration_id_input uuid)
returns void language sql security invoker set search_path = '' as $$
 select private.native_mark_opportunity_attendance(registration_id_input);
$$;

revoke all on function private.can_manage_opportunity_registration(uuid),public.native_my_registrations(),private.native_cancel_opportunity_registration(uuid),public.native_cancel_opportunity_registration(uuid),private.native_opportunity_attendees(uuid),public.native_opportunity_attendees(uuid),private.native_mark_opportunity_attendance(uuid),public.native_mark_opportunity_attendance(uuid) from public,anon;
grant execute on function private.can_manage_opportunity_registration(uuid),public.native_my_registrations(),private.native_cancel_opportunity_registration(uuid),public.native_cancel_opportunity_registration(uuid),private.native_opportunity_attendees(uuid),public.native_opportunity_attendees(uuid),private.native_mark_opportunity_attendance(uuid),public.native_mark_opportunity_attendance(uuid) to authenticated;
