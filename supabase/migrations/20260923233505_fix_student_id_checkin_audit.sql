create or replace function private.native_staff_check_in(presented_token text,requested_event_id uuid,id_checked_input boolean)
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
   update public.ticket_scans set id_checked=true where id=(
    select ts.id from public.ticket_scans ts
    where ts.ticket_id=matched_ticket_id and ts.result='accepted'
    order by ts.scanned_at desc limit 1
   );
  end if;
  return next;
 end loop;
end $$;
