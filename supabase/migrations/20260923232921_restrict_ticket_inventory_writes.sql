-- All ticket inventory changes must use guarded RPCs so school admins are scoped,
-- capacity constraints run, and adjustments carry an audit reason.
revoke insert, update, delete on public.events from authenticated;
revoke insert, update, delete on public.ticket_allocations from authenticated;
revoke insert, update, delete on public.venues from authenticated;

-- The old one-step reservation bypasses the visible five-minute checkout.
revoke all on function public.native_reserve_tickets(uuid,integer,text) from public,anon,authenticated;
revoke all on function public.create_ticket_hold(uuid,integer,text) from public,anon;
revoke all on function public.scan_ticket(text,uuid) from public,anon,authenticated;
