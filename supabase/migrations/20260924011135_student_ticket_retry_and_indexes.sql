create or replace function private.issue_ticket(requested_hold_id uuid)
returns table(ticket_id uuid,token text) language plpgsql security definer set search_path = '' as $$
declare h public.ticket_holds%rowtype; a public.ticket_allocations%rowtype; e public.events%rowtype; issued record;
begin
 select * into h from public.ticket_holds where id=requested_hold_id and user_id=auth.uid();
 if h.id is null then raise exception 'Hold unavailable'; end if;
 if h.status='converted' then return; end if;
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

create index if not exists ticket_holds_assigned_youth_active_idx
 on public.ticket_holds(assigned_youth_profile_id,expires_at)
 where status='active' and assigned_youth_profile_id is not null;
create index if not exists tickets_assigned_youth_active_idx
 on public.tickets(assigned_youth_profile_id)
 where status in ('issued','scanned') and assigned_youth_profile_id is not null;
create index if not exists student_school_verifications_requested_by_idx
 on public.student_school_verifications(requested_by);
create index if not exists student_school_verifications_verified_by_idx
 on public.student_school_verifications(verified_by) where verified_by is not null;
