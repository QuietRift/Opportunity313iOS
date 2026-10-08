-- Legacy linked child profiles may carry youth_account. Treat active guardian
-- relationships as managed access regardless of that legacy label.
create or replace function private.can_manage_opportunity_registration(registration_id_input uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
  select 1 from public.opportunity_tickets t where t.id=registration_id_input and (
   t.attendee_user_id=auth.uid() or
   exists(select 1 from public.youth_profiles yp where yp.id=t.youth_profile_id and yp.user_id=auth.uid()
    and yp.account_type='youth_account' and yp.age_band ~ '^(18|19|20|21|22|23|24)[–-]'
    and not exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=yp.id and gr.status='active')) or
   (public.has_role(auth.uid(),'parent') and exists(select 1 from public.guardian_relationships gr where gr.youth_profile_id=t.youth_profile_id and gr.guardian_user_id=auth.uid() and gr.status='active'))
  )
 );
$$;
