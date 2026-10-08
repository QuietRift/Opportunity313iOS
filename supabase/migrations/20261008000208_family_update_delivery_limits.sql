create or replace function private.native_register_family(opportunity_id_input uuid, youth_profile_ids_input uuid[], include_self_input boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb := '[]'; child uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if coalesce(cardinality(youth_profile_ids_input),0) + (case when coalesce(include_self_input,false) then 1 else 0 end) >20 or (coalesce(cardinality(youth_profile_ids_input),0)=0 and not coalesce(include_self_input,false)) then raise exception 'Select between one and twenty attendees'; end if;
 perform 1 from public.opportunities where id=opportunity_id_input for update;
 if include_self_input then result := result || jsonb_build_array(private.native_register_opportunity(opportunity_id_input,null)); end if;
 for child in select distinct unnest(youth_profile_ids_input) loop
  if child is null then raise exception 'Invalid attendee'; end if;
  result := result || jsonb_build_array(private.native_register_opportunity(opportunity_id_input,child));
 end loop;
 return result;
end $$;

-- Bound each lease to at most five fifteen-second delivery requests.
create or replace function public.claim_registration_push_events() returns table(id uuid,lease_id uuid,token text,notification_id uuid,opportunity_id uuid) language sql security invoker set search_path='' as $$
 with candidates as(select q.id from public.registration_push_queue q join public.registration_notifications n on n.id=q.notification_id join public.registration_push_devices d on d.token=q.token and d.user_id=n.recipient_id
 where not q.finished and q.attempts<6 and q.next_attempt_at<=now() and (q.lease_until is null or q.lease_until<now()) and n.created_at>now()-interval '24 hours'
 and exists(select 1 from public.opportunity_tickets t where t.opportunity_id=n.opportunity_id and (t.attendee_user_id=n.recipient_id or exists(select 1 from public.youth_profiles y where y.id=t.youth_profile_id and y.user_id=n.recipient_id) or exists(select 1 from public.guardian_relationships g where g.youth_profile_id=t.youth_profile_id and g.guardian_user_id=n.recipient_id and g.status='active')))
 order by q.next_attempt_at limit 5 for update of q skip locked), claimed as(update public.registration_push_queue q set lease_id=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1 from candidates c where q.id=c.id returning q.*)
 select c.id,c.lease_id,c.token,c.notification_id,n.opportunity_id from claimed c join public.registration_notifications n on n.id=c.notification_id;
$$;
