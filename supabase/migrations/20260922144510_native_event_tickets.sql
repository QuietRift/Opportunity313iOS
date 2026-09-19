-- Native ticketing uses existing events, allocations, holds, tickets and scan audit.
-- No sample events are published or altered by this migration.
create schema if not exists private;
grant usage on schema private to authenticated;

-- Keep privileged implementations out of the exposed API schema.
alter function public.issue_ticket(uuid) set schema private;
create or replace function private.issue_ticket(requested_hold_id uuid)
returns table(ticket_id uuid, token text) language plpgsql security definer set search_path = '' as $$
declare h public.ticket_holds%rowtype; a public.ticket_allocations%rowtype;
 e public.events%rowtype; raw_token text; i integer; eid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select ta.event_id into eid from public.ticket_holds th join public.ticket_allocations ta on ta.id=th.allocation_id where th.id=requested_hold_id and th.user_id=auth.uid();
 if eid is null then raise exception 'Hold unavailable'; end if;
 -- Consistent event -> allocation -> hold lock order matches hold creation.
 select * into e from public.events where id=eid for update;
 select ta.* into a from public.ticket_allocations ta join public.ticket_holds th on th.allocation_id=ta.id where th.id=requested_hold_id for update of ta;
 select * into h from public.ticket_holds where id=requested_hold_id for update;
 if h.user_id<>auth.uid() then raise exception 'Hold unavailable'; end if;
 -- A retry must never issue additional tickets. The wallet recovers confirmations.
 if h.status='converted' then return; end if;
 if h.status<>'active' or h.expires_at<=now() then raise exception 'Reservation expired. Please try again.'; end if;
 if not a.active or e.event_status<>'on_sale' or now()<e.sales_open_at or now()>=e.sales_close_at or now()>=e.starts_at then raise exception 'Reservations are closed for this event'; end if;
 for i in 1..h.quantity loop
  raw_token := encode(extensions.gen_random_bytes(32),'hex');
  insert into public.tickets(allocation_id,claimed_by,token_hash,status)
   values(h.allocation_id,h.user_id,encode(extensions.digest(raw_token,'sha256'),'hex'),'issued') returning id into ticket_id;
  token := raw_token; return next;
 end loop;
 update public.ticket_holds set status='converted',updated_at=now() where id=h.id;
end $$;
create function public.issue_ticket(requested_hold_id uuid)
returns table(ticket_id uuid, token text) language sql security invoker set search_path = '' as $$ select * from private.issue_ticket(requested_hold_id) $$;

create function private.native_reserve_tickets(allocation_id_input uuid, quantity_input integer, request_id_input text)
returns table(ticket_id uuid,token text) language plpgsql security definer set search_path = '' as $$
declare h public.ticket_holds%rowtype; eid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if quantity_input is null or quantity_input<1 or quantity_input>20 then raise exception 'Choose between 1 and 20 tickets'; end if;
 if request_id_input is null or length(request_id_input)<8 or length(request_id_input)>100 then raise exception 'Invalid reservation request'; end if;
 select event_id into eid from public.ticket_allocations where id=allocation_id_input;
 if eid is null then raise exception 'Ticket option unavailable'; end if;
 perform 1 from public.events where id=eid for update;
 h := public.create_ticket_hold(allocation_id_input,quantity_input,'native:'||auth.uid()::text||':'||request_id_input);
 return query select * from private.issue_ticket(h.id);
end $$;
create function public.native_reserve_tickets(allocation_id_input uuid, quantity_input integer, request_id_input text)
returns table(ticket_id uuid,token text) language sql security invoker set search_path = '' as $$ select * from private.native_reserve_tickets(allocation_id_input,quantity_input,request_id_input) $$;

create function private.native_ticket_events(managed_only boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(data order by starts_at) from (
  select e.starts_at,jsonb_build_object('id',e.id,'title',e.title,'sport',e.sport,'starts_at',e.starts_at,'timezone',e.timezone,
  'sales_open_at',e.sales_open_at,'sales_close_at',e.sales_close_at,'event_status',e.event_status,'is_demo',e.is_demo,
  'venue_name',v.name,'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),'can_manage',public.manages_event(e.id),
  'allocations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'limit_per_user',a.purchase_limit_per_user,
    'remaining',greatest(0,a.capacity-(select count(*) from public.tickets t where t.allocation_id=a.id and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.status='active' and h.expires_at>now())),
    'my_remaining',greatest(0,a.purchase_limit_per_user-(select count(*) from public.tickets t where t.allocation_id=a.id and t.claimed_by=auth.uid() and t.status in ('issued','scanned'))-
      (select coalesce(sum(h.quantity),0) from public.ticket_holds h where h.allocation_id=a.id and h.user_id=auth.uid() and h.status='active' and h.expires_at>now()))
    ) order by a.name) from public.ticket_allocations a where a.event_id=e.id and a.active),'[]'::jsonb)) as data
  from public.events e join public.venues v on v.id=e.venue_id
  where (managed_only and public.manages_event(e.id)) or (not managed_only and e.event_status in ('published','on_sale','sold_out') and e.starts_at>now())
 ) q),'[]'::jsonb);
end $$;
create function public.native_ticket_events(managed_only boolean default false)
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_ticket_events(managed_only) $$;

create function private.native_ticket_wallet(event_id_input uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if event_id_input is not null and not public.manages_event(event_id_input) then raise exception 'Event staff access required'; end if;
 return coalesce((select jsonb_agg(data order by issued_at desc) from (
  select t.issued_at,jsonb_build_object('id',t.id,'event_id',e.id,'event_title',e.title,'allocation_name',a.name,'starts_at',e.starts_at,
   'timezone',e.timezone,'venue_name',v.name,'address',concat_ws(', ',v.street,v.city,v.state,v.postal_code),
   'status',t.status,'event_status',e.event_status,'is_demo',e.is_demo,'issued_at',t.issued_at) data
  from public.tickets t join public.ticket_allocations a on a.id=t.allocation_id join public.events e on e.id=a.event_id join public.venues v on v.id=e.venue_id
  where (event_id_input is null and t.claimed_by=auth.uid()) or (event_id_input is not null and e.id=event_id_input)
 ) q),'[]'::jsonb);
end $$;
create function public.native_ticket_wallet(event_id_input uuid default null)
returns jsonb language sql security invoker set search_path = '' as $$ select private.native_ticket_wallet(event_id_input) $$;

create function private.native_replace_ticket_code(ticket_id_input uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare t public.tickets%rowtype; e public.events%rowtype; raw_token text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select ev.* into e from public.events ev join public.ticket_allocations a on a.event_id=ev.id join public.tickets tk on tk.allocation_id=a.id where tk.id=ticket_id_input for update of ev;
 select * into t from public.tickets where id=ticket_id_input for update;
 if t.id is null or t.claimed_by<>auth.uid() then raise exception 'Ticket unavailable'; end if;
 if t.status<>'issued' or e.event_status in ('cancelled','completed') then raise exception 'This ticket is no longer valid for entry'; end if;
 raw_token := encode(extensions.gen_random_bytes(32),'hex');
 update public.tickets set token_hash=encode(extensions.digest(raw_token,'sha256'),'hex'),updated_at=now() where id=t.id;
 return raw_token;
end $$;
create function public.native_replace_ticket_code(ticket_id_input uuid)
returns text language sql security invoker set search_path = '' as $$ select private.native_replace_ticket_code(ticket_id_input) $$;

create function private.native_cancel_ticket(ticket_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare t public.tickets%rowtype; e public.events%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select ev.* into e from public.events ev join public.ticket_allocations a on a.event_id=ev.id join public.tickets tk on tk.allocation_id=a.id where tk.id=ticket_id_input for update of ev;
 select * into t from public.tickets where id=ticket_id_input for update;
 if t.id is null or t.claimed_by<>auth.uid() then raise exception 'Ticket unavailable'; end if;
 if t.status='void' then return; end if;
 if t.status<>'issued' or e.starts_at<=now() then raise exception 'Only unused tickets can be cancelled before the event starts'; end if;
 update public.tickets set status='void',updated_at=now() where id=t.id;
end $$;
create function public.native_cancel_ticket(ticket_id_input uuid)
returns void language sql security invoker set search_path = '' as $$ select private.native_cancel_ticket(ticket_id_input) $$;

alter function public.scan_ticket(text,uuid) set schema private;
create function private.native_scan_ticket(presented_token text, requested_event_id uuid)
returns table(matched_ticket_id uuid,result public.scan_result) language plpgsql security definer set search_path = '' as $$
declare state public.event_status;
begin
 if auth.uid() is null or not public.manages_event(requested_event_id) then raise exception 'Event staff access required'; end if;
 select event_status into state from public.events where id=requested_event_id for update;
 if state is null or state in ('draft','cancelled','completed') then raise exception 'Check-in is closed for this event'; end if;
 if presented_token is null or length(presented_token)<>64 then raise exception 'Enter a valid ticket code'; end if;
 return query select * from private.scan_ticket(presented_token,requested_event_id);
end $$;
create function public.scan_ticket(presented_token text, requested_event_id uuid)
returns table(matched_ticket_id uuid,result public.scan_result) language sql security invoker set search_path = '' as $$ select * from private.native_scan_ticket(presented_token,requested_event_id) $$;

-- No anonymous execution of ticket endpoints. Tables retain their existing RLS.
revoke all on function private.scan_ticket(text,uuid) from public,anon,authenticated;
revoke all on function public.issue_ticket(uuid) from public,anon;
grant execute on function public.issue_ticket(uuid) to authenticated;
revoke all on function private.issue_ticket(uuid) from public,anon;
grant execute on function private.issue_ticket(uuid) to authenticated;
revoke all on function public.native_reserve_tickets(uuid,integer,text) from public,anon;
grant execute on function public.native_reserve_tickets(uuid,integer,text) to authenticated;
revoke all on function private.native_reserve_tickets(uuid,integer,text) from public,anon;
grant execute on function private.native_reserve_tickets(uuid,integer,text) to authenticated;
revoke all on function public.native_ticket_events(boolean) from public,anon;
grant execute on function public.native_ticket_events(boolean) to authenticated;
revoke all on function private.native_ticket_events(boolean) from public,anon;
grant execute on function private.native_ticket_events(boolean) to authenticated;
revoke all on function public.native_ticket_wallet(uuid) from public,anon;
grant execute on function public.native_ticket_wallet(uuid) to authenticated;
revoke all on function private.native_ticket_wallet(uuid) from public,anon;
grant execute on function private.native_ticket_wallet(uuid) to authenticated;
revoke all on function public.native_replace_ticket_code(uuid) from public,anon;
grant execute on function public.native_replace_ticket_code(uuid) to authenticated;
revoke all on function private.native_replace_ticket_code(uuid) from public,anon;
grant execute on function private.native_replace_ticket_code(uuid) to authenticated;
revoke all on function public.native_cancel_ticket(uuid) from public,anon;
grant execute on function public.native_cancel_ticket(uuid) to authenticated;
revoke all on function private.native_cancel_ticket(uuid) from public,anon;
grant execute on function private.native_cancel_ticket(uuid) to authenticated;
revoke all on function private.native_scan_ticket(text,uuid) from public,anon;
grant execute on function private.native_scan_ticket(text,uuid) to authenticated;
revoke all on function public.scan_ticket(text,uuid) from public,anon;
grant execute on function public.scan_ticket(text,uuid) to authenticated;
