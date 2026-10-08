-- In-app registration is an explicit provider opt-in. External links remain external.
create table public.opportunity_tickets (
 id uuid primary key default gen_random_uuid(),
 opportunity_id uuid not null references public.opportunities(id) on delete cascade,
 registered_by uuid references auth.users(id) on delete set null,
 attendee_user_id uuid references auth.users(id) on delete cascade,
 youth_profile_id uuid references public.youth_profiles(id) on delete cascade,
 attendee_name text not null,
 opportunity_name text not null,
 starts_at timestamptz,
 ends_at timestamptz,
 timezone text not null,
 location text not null,
 address text not null,
 status text not null default 'upcoming' check (status in ('upcoming','used','cancelled','expired')),
 entry_code text not null default encode(extensions.gen_random_bytes(32),'hex'),
 is_demo boolean not null,
 created_at timestamptz not null default now(),
 check ((attendee_user_id is null) <> (youth_profile_id is null))
);
create unique index opportunity_tickets_adult_unique on public.opportunity_tickets(opportunity_id,attendee_user_id) where attendee_user_id is not null and status <> 'cancelled';
create unique index opportunity_tickets_youth_unique on public.opportunity_tickets(opportunity_id,youth_profile_id) where youth_profile_id is not null and status <> 'cancelled';
create index opportunity_tickets_youth_lookup on public.opportunity_tickets(youth_profile_id);
create index opportunity_tickets_registrant_lookup on public.opportunity_tickets(registered_by);
alter table public.opportunity_tickets enable row level security;
revoke all on public.opportunity_tickets from anon, authenticated;
grant select on public.opportunity_tickets to authenticated;
create policy family_read_opportunity_tickets on public.opportunity_tickets for select to authenticated using (
 attendee_user_id = (select auth.uid()) or
 exists(select 1 from public.youth_profiles yp where yp.id=youth_profile_id and yp.user_id=(select auth.uid())) or
 exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=opportunity_tickets.youth_profile_id and gr.guardian_user_id=(select auth.uid()) and gr.status='active')
);

create function private.native_register_opportunity(opportunity_id_input uuid, youth_profile_id_input uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 actor uuid := auth.uid();
 o public.opportunities%rowtype;
 y public.youth_profiles%rowtype;
 t public.opportunity_tickets%rowtype;
 attendee text;
 is_parent boolean;
 age_bounds text[];
begin
 if actor is null then raise exception 'Authentication required'; end if;
 select exists(select 1 from public.user_roles where user_id=actor and role='parent') into is_parent;
 if not is_parent and not exists(select 1 from public.user_roles where user_id=actor and role='youth') then
  raise exception 'A parent or youth account is required';
 end if;
 if youth_profile_id_input is null then
  if not is_parent then raise exception 'Select your youth profile'; end if;
  select coalesce(nullif(btrim(display_name),''),'Parent / guardian') into attendee from public.profiles where user_id=actor;
  attendee := coalesce(attendee,'Parent / guardian');
 else
  select * into y from public.youth_profiles yp where yp.id=youth_profile_id_input and (
   (not is_parent and yp.user_id=actor) or
   (is_parent and exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=yp.id and gr.guardian_user_id=actor and gr.status='active'))
  ) for share;
  if y.id is null then raise exception 'Attendee unavailable'; end if;
  attendee := y.first_name;
 end if;
 -- Lock the opportunity so simultaneous registrations cannot oversell capacity.
 select * into o from public.opportunities where id=opportunity_id_input for update;
 if o.id is null or o.status <> 'published' then raise exception 'Opportunity unavailable'; end if;
 if o.registration_method <> 'in_app' or not o.is_free or o.cost_cents <> 0 then
  raise exception 'Complete registration with the provider for this opportunity';
 end if;
 -- Return the existing ticket on retries, including a retry after the deadline.
 select * into t from public.opportunity_tickets where opportunity_id=o.id and status <> 'cancelled' and (
  (youth_profile_id_input is null and attendee_user_id=actor) or youth_profile_id=youth_profile_id_input
 );
 if t.id is not null then return to_jsonb(t); end if;
 if (o.deadline is not null and now() >= o.deadline) or
    (o.starts_at is not null and now() >= o.starts_at) then raise exception 'Registration has closed'; end if;
 if y.id is not null then
  age_bounds := regexp_match(replace(y.age_band,'–','-'), '^([0-9]+)-([0-9]+)$');
  if age_bounds is not null and ((o.age_min is not null and age_bounds[2]::int < o.age_min) or (o.age_max is not null and age_bounds[1]::int > o.age_max)) then
   raise exception 'This opportunity is not available for the attendee age group';
  end if;
  if y.grade is not null and ((o.grade_min is not null and y.grade < o.grade_min) or (o.grade_max is not null and y.grade > o.grade_max)) then
   raise exception 'This opportunity is not available for the attendee grade';
  end if;
  if (y.gender='boy' and o.gender_eligibility='girls') or (y.gender='girl' and o.gender_eligibility='boys') then
   raise exception 'This opportunity is not available for the attendee';
  end if;
 end if;
 if o.capacity is not null and (select count(*) from public.opportunity_tickets where opportunity_id=o.id and status <> 'cancelled') >= o.capacity then
  raise exception 'This opportunity is full';
 end if;
 insert into public.opportunity_tickets(opportunity_id,registered_by,attendee_user_id,youth_profile_id,attendee_name,opportunity_name,starts_at,ends_at,timezone,location,address,is_demo)
 values(o.id,actor,case when y.id is null then actor end,y.id,attendee,o.title,o.starts_at,o.ends_at,o.timezone,o.location_name,concat_ws(', ',o.street,o.city,o.state,o.postal_code),o.is_demo)
 returning * into t;
 return to_jsonb(t);
end $$;
create function public.native_register_opportunity(opportunity_id_input uuid, youth_profile_id_input uuid default null)
returns jsonb language sql security invoker set search_path = '' as $$
 select private.native_register_opportunity(opportunity_id_input,youth_profile_id_input);
$$;
revoke all on function private.native_register_opportunity(uuid,uuid), public.native_register_opportunity(uuid,uuid) from public,anon;
grant execute on function private.native_register_opportunity(uuid,uuid), public.native_register_opportunity(uuid,uuid) to authenticated;

-- The existing event wallet also follows family relationships; child accounts
-- never inherit all tickets claimed by their parent.
create or replace function private.native_ticket_wallet(event_id_input uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if event_id_input is not null and not public.manages_event(event_id_input) then raise exception 'Event staff access required'; end if;
 return coalesce((select jsonb_agg(data order by issued_at desc) from (
  select t.issued_at,jsonb_build_object('id',t.id,'event_id',e.id,'event_title',e.title,'allocation_name',a.name,
   'assigned_youth_name',yp.first_name,'starts_at',e.starts_at,'timezone',e.timezone,'venue_name',v.name,
   'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),
   'status',t.status,'event_status',e.event_status,'is_demo',e.is_demo,'issued_at',t.issued_at,
   'can_manage_reservation',t.claimed_by=auth.uid()) data
  from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id
  join public.events e on e.id=a.event_id join public.venues v on v.id=e.venue_id
  left join public.youth_profiles yp on yp.id=t.assigned_youth_profile_id
  where (event_id_input is null and (
   (t.assigned_youth_profile_id is null and t.claimed_by=auth.uid()) or yp.user_id=auth.uid() or
   exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=yp.id and gr.guardian_user_id=auth.uid() and gr.status='active')
  )) or (event_id_input is not null and e.id=event_id_input)
 ) q),'[]'::jsonb);
end $$;

create or replace function private.native_replace_ticket_code(ticket_id_input uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare t public.tickets%rowtype; e public.events%rowtype; raw_token text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select ev.* into e from public.events ev join public.ticket_allocations a on a.event_id=ev.id join public.tickets tk on tk.allocation_id=a.id where tk.id=ticket_id_input for update of ev;
 select * into t from public.tickets where id=ticket_id_input for update;
 if t.id is null or not (
  (t.assigned_youth_profile_id is null and t.claimed_by=auth.uid()) or
  exists(select 1 from public.youth_profiles yp where yp.id=t.assigned_youth_profile_id and yp.user_id=auth.uid()) or
  exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=t.assigned_youth_profile_id and gr.guardian_user_id=auth.uid() and gr.status='active')
 ) then raise exception 'Ticket unavailable'; end if;
 if t.status<>'issued' or e.event_status in ('cancelled','completed','draft') then raise exception 'This ticket is no longer valid for entry'; end if;
 raw_token := encode(extensions.gen_random_bytes(32),'hex');
 update public.tickets set token_hash=encode(extensions.digest(raw_token,'sha256'),'hex'),updated_at=now() where id=t.id;
 return raw_token;
end $$;
