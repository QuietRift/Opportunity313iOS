-- One-time follow-up already applied to the Opportunity313 test backend.
-- Keep Sarai's existing profile, family relationship, age, grade, interests,
-- saves, and history. Map the child2 test login to that profile.
BEGIN;
DO $link$
DECLARE
  parent_id uuid := '4240d906-85cd-4ea4-8f61-78b85fda3be1';
  child_user_id uuid := '457100de-1473-4238-b383-e085ff2d14bd';
  sarai_id uuid := '836b1250-4eab-49cb-ab54-f6c14e410c3f';
  disposable_id uuid := 'b66bd780-74be-414e-8d03-33b778534a4c';
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('opportunity313-standard-test-accounts'));
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=child_user_id
      AND email='child2@opportunity313.com'
      AND raw_app_meta_data->>'test_fixture'='opportunity313-standard-2026-09-26')
    OR NOT EXISTS (SELECT 1 FROM public.youth_profiles WHERE id=sarai_id
      AND first_name='Sarai' AND account_type='parent_managed' AND user_id IS NULL)
    OR NOT EXISTS (SELECT 1 FROM public.guardian_relationships WHERE guardian_user_id=parent_id
      AND youth_profile_id=sarai_id AND status='active')
    OR NOT EXISTS (SELECT 1 FROM public.youth_profiles WHERE id=disposable_id
      AND account_type='youth_account' AND user_id=child_user_id)
    OR EXISTS (SELECT 1 FROM public.child_access_credentials WHERE youth_profile_id=sarai_id)
  THEN RAISE EXCEPTION 'Expected Sarai/Child2 state changed; aborting'; END IF;
  IF EXISTS (SELECT 1 FROM public.opportunity_saves WHERE youth_profile_id=disposable_id)
    OR EXISTS (SELECT 1 FROM public.opportunity_interests WHERE youth_profile_id=disposable_id)
    OR EXISTS (SELECT 1 FROM public.registrations WHERE youth_profile_id=disposable_id)
    OR EXISTS (SELECT 1 FROM public.consents WHERE youth_profile_id=disposable_id)
    OR EXISTS (SELECT 1 FROM public.tickets WHERE assigned_youth_profile_id=disposable_id)
    OR EXISTS (SELECT 1 FROM public.ticket_holds WHERE assigned_youth_profile_id=disposable_id)
  THEN RAISE EXCEPTION 'Disposable Child2 profile now has activity; aborting'; END IF;
  DELETE FROM public.youth_profiles WHERE id=disposable_id;
  UPDATE public.youth_profiles SET account_type='youth_account',user_id=child_user_id,
    updated_at=now() WHERE id=sarai_id;
  UPDATE public.profiles SET display_name='Sarai' WHERE user_id=child_user_id;
  UPDATE auth.users SET raw_user_meta_data=coalesce(raw_user_meta_data,'{}'::jsonb)
    ||jsonb_build_object('display_name','Sarai','full_name','Sarai')
    WHERE id=child_user_id;
END $link$;
COMMIT;
