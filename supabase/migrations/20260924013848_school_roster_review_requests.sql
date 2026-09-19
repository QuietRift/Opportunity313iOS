-- The student's ID photo stays on the device. Capturing it sends only a review
-- request to the selected school's admins; approval requires a roster check.
alter table public.student_school_verifications add column photo_step_completed_at timestamptz;

create or replace function private.reset_school_verification_after_identity_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.first_name is distinct from old.first_name or new.grade is distinct from old.grade then
  update public.student_school_verifications set status='pending',verified_by=null,
   reviewed_at=null,photo_step_completed_at=null,requested_at=now(),updated_at=now()
   where youth_profile_id=new.id and status='verified';
 end if;
 return new;
end $$;

create or replace function private.native_request_school_verification(youth_profile_id_input uuid,school_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.can_claim_youth_profile(youth_profile_id_input) then raise exception 'Youth profile unavailable'; end if;
 if not exists(select 1 from public.schools where id=school_id_input) then raise exception 'School unavailable'; end if;
 insert into public.student_school_verifications(youth_profile_id,school_id,status,requested_by)
 values(youth_profile_id_input,school_id_input,'pending',auth.uid())
 on conflict(youth_profile_id) do update set school_id=excluded.school_id,status='pending',
  requested_by=auth.uid(),requested_at=now(),reviewed_at=null,verified_by=null,
  photo_step_completed_at=null,updated_at=now()
 where public.student_school_verifications.school_id is distinct from excluded.school_id
    or public.student_school_verifications.status in ('rejected','revoked');
end $$;

create function private.native_submit_school_roster_request(youth_profile_id_input uuid,school_id_input uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.can_claim_youth_profile(youth_profile_id_input) then raise exception 'Youth profile unavailable'; end if;
 update public.student_school_verifications set photo_step_completed_at=now(),
  requested_at=now(),updated_at=now()
 where youth_profile_id=youth_profile_id_input and school_id=school_id_input
  and status='pending' and photo_step_completed_at is null;
 if not found then raise exception 'Choose a school before submitting the ID photo'; end if;
end $$;
create function public.native_submit_school_roster_request(youth_profile_id_input uuid,school_id_input uuid)
returns void language sql security invoker set search_path = '' as $$
 select private.native_submit_school_roster_request(youth_profile_id_input,school_id_input)
$$;

create or replace function private.native_my_school_profiles()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'youth_profile_id',yp.id,'youth_name',yp.first_name,'grade',yp.grade,
  'verification_id',sv.id,'school_id',sv.school_id,'school_name',s.name,
  'status',coalesce(sv.status,'not_linked'),'photo_submitted',sv.photo_step_completed_at is not null
 ) order by yp.first_name)
 from public.youth_profiles yp
 left join public.student_school_verifications sv on sv.youth_profile_id=yp.id
 left join public.schools s on s.id=sv.school_id
 where yp.user_id=auth.uid() or exists(
  select 1 from public.guardian_relationships gr where gr.youth_profile_id=yp.id
   and gr.guardian_user_id=auth.uid() and gr.status='active'
 )),'[]'::jsonb);
end $$;

create or replace function private.native_school_verification_queue()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.has_role(auth.uid(),'athletics') then raise exception 'School staff access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',sv.id,'youth_profile_id',sv.youth_profile_id,
  'youth_name',yp.first_name,'grade',yp.grade,'school_id',s.id,'school_name',s.name,
  'status',sv.status,'requested_at',sv.requested_at) order by sv.requested_at desc)
 from public.student_school_verifications sv
 join public.youth_profiles yp on yp.id=sv.youth_profile_id
 join public.schools s on s.id=sv.school_id
 where private.can_verify_school_students(sv.school_id)
  and (sv.status='verified' or (sv.status='pending' and sv.photo_step_completed_at is not null))),'[]'::jsonb);
end $$;

create function private.native_review_school_roster(verification_id_input uuid,approve_input boolean,roster_checked_input boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare request_row public.student_school_verifications%rowtype;
begin
 select * into request_row from public.student_school_verifications where id=verification_id_input for update;
 if request_row.id is null or not private.can_verify_school_students(request_row.school_id) then
  raise exception 'School verification request unavailable';
 end if;
 if approve_input and (request_row.status<>'pending' or request_row.photo_step_completed_at is null) then
  raise exception 'Student ID request is not ready for roster review';
 end if;
 if approve_input and not coalesce(roster_checked_input,false) then
  raise exception 'Check the school roster before approval';
 end if;
 if not approve_input and request_row.status not in ('pending','verified') then raise exception 'This request is already closed'; end if;
 update public.student_school_verifications set
  status=case when approve_input then 'verified' when request_row.status='verified' then 'revoked' else 'rejected' end,
  verified_by=auth.uid(),reviewed_at=now(),updated_at=now() where id=request_row.id;
end $$;
create function public.native_review_school_roster(verification_id_input uuid,approve_input boolean,roster_checked_input boolean)
returns void language sql security invoker set search_path = '' as $$
 select private.native_review_school_roster(verification_id_input,approve_input,roster_checked_input)
$$;

-- Supersede the older endpoint that recorded an in-person ID check.
revoke execute on function private.native_review_school_verification(uuid,boolean,boolean),
 public.native_review_school_verification(uuid,boolean,boolean) from authenticated;
revoke all on function private.native_submit_school_roster_request(uuid,uuid),
 public.native_submit_school_roster_request(uuid,uuid),
 private.native_review_school_roster(uuid,boolean,boolean),
 public.native_review_school_roster(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function private.native_submit_school_roster_request(uuid,uuid),
 public.native_submit_school_roster_request(uuid,uuid),
 private.native_review_school_roster(uuid,boolean,boolean),
 public.native_review_school_roster(uuid,boolean,boolean) to authenticated;
