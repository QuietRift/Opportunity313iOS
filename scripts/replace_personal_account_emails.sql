-- One-time follow-up to the initial fixture seed; reviewed against the live schema.
-- Run in one transaction with app.test_account_password set. No personal email
-- literals or passwords are stored in this file. Existing original user IDs survive.
DO $replace$
DECLARE
  mapping record;
  original_ids uuid[] := ARRAY['4240d906-85cd-4ea4-8f61-78b85fda3be1','897c1a5e-5c2d-4c53-a258-14f4207c1432','b1900f6f-9787-4f89-8506-a6e723b58d56','f1fbaddc-6b09-4056-914e-03cc5e467a4e']::uuid[];
  duplicate_ids uuid[] := ARRAY['f97c50f6-ed5b-477f-b727-1941877ffb47','e243b215-2de0-4251-873e-8aebed260e09','dad1a6a7-6096-4889-944d-25d44566774f','55184ab6-a4f1-4af5-87f2-8a6cd4a59aab']::uuid[];
  fixture_profile uuid := '4acdafb7-730d-4055-9bbc-9f0a05f93a61';
  fixture_org uuid := 'e2a82a81-9b7e-457e-8f45-7ef7d4e7aafc';
  fk record;
  n bigint;
  test_password text := current_setting('app.test_account_password',true);
BEGIN
  IF test_password IS NULL OR length(test_password)<12 THEN RAISE EXCEPTION 'Password required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('opportunity313-standard-test-accounts'));
  IF (SELECT count(*) FROM auth.users WHERE id=ANY(duplicate_ids) AND raw_app_meta_data->>'test_fixture'='opportunity313-standard-2026-09-26')<>4 THEN
    RAISE EXCEPTION 'Expected fresh duplicate fixtures not found; aborting';
  END IF;
  IF (SELECT count(*) FROM auth.users WHERE id=ANY(original_ids))<>4 THEN RAISE EXCEPTION 'Original accounts missing'; END IF;

  -- Refuse cleanup if any new business data has attached to the duplicate users.
  FOR fk IN SELECT c.conrelid::regclass AS tbl,a.attname AS col
    FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
    WHERE c.contype='f' AND c.confrelid='auth.users'::regclass
      AND c.conrelid::regclass::text NOT LIKE 'auth.%'
      AND c.conrelid NOT IN ('public.profiles'::regclass,'public.user_roles'::regclass,
        'public.org_members'::regclass,'public.guardian_relationships'::regclass,'public.youth_profiles'::regclass)
  LOOP
    EXECUTE format('select count(*) from %s where %I=ANY($1)',fk.tbl,fk.col) INTO n USING duplicate_ids;
    IF n>0 THEN RAISE EXCEPTION 'Duplicate has business references in %',fk.tbl; END IF;
  END LOOP;
  -- Ensure the disposable youth profile and organization have no business content.
  FOR fk IN SELECT c.conrelid::regclass AS tbl,a.attname AS col,c.confrelid AS target
    FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
    WHERE c.contype='f' AND c.confrelid IN ('public.youth_profiles'::regclass,'public.organizations'::regclass)
      AND c.conrelid NOT IN ('public.guardian_relationships'::regclass,'public.org_members'::regclass)
  LOOP
    EXECUTE format('select count(*) from %s where %I=$1',fk.tbl,fk.col) INTO n
      USING CASE WHEN fk.target='public.youth_profiles'::regclass THEN fixture_profile ELSE fixture_org END;
    IF n>0 THEN RAISE EXCEPTION 'Fixture has business references in %',fk.tbl; END IF;
  END LOOP;

  -- Move the second new youth profile to the preserved original parent.
  UPDATE public.guardian_relationships SET guardian_user_id=original_ids[1]
  WHERE guardian_user_id=duplicate_ids[1] AND youth_profile_id='b66bd780-74be-414e-8d03-33b778534a4c';
  IF NOT FOUND THEN RAISE EXCEPTION 'Child2 relationship missing'; END IF;
  DELETE FROM public.youth_profiles WHERE id=fixture_profile AND user_id=duplicate_ids[2];
  DELETE FROM public.organizations WHERE id=fixture_org AND is_demo;
  DELETE FROM auth.users WHERE id=ANY(duplicate_ids);

  FOR mapping IN SELECT * FROM (VALUES
    (original_ids[1],'parent','Test Parent'),
    (original_ids[2],'child1','Test Child 1'),
    (original_ids[3],'provider','Test Provider'),
    (original_ids[4],'admin','Test Admin')
  ) AS m(uid,alias,display_name)
  LOOP
    UPDATE auth.users SET email=mapping.alias||'@opportunity313.com',
      encrypted_password=extensions.crypt(test_password,extensions.gen_salt('bf',10)),
      email_confirmed_at=coalesce(email_confirmed_at,now()),
      email_change='',email_change_token_new='',email_change_token_current='',
      email_change_confirm_status=0,email_change_sent_at=null,confirmation_token='',recovery_token='',
      raw_user_meta_data=coalesce(raw_user_meta_data,'{}'::jsonb)||jsonb_build_object(
        'email',mapping.alias||'@opportunity313.com','display_name',mapping.display_name,'full_name',mapping.display_name),
      raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||jsonb_build_object('test_fixture','opportunity313-standard-2026-09-26'),
      updated_at=now()
    WHERE id=mapping.uid;
    UPDATE auth.identities SET identity_data=identity_data||jsonb_build_object('email',mapping.alias||'@opportunity313.com','email_verified',true),updated_at=now()
    WHERE user_id=mapping.uid AND provider='email';
    UPDATE public.profiles SET display_name=mapping.display_name,updated_at=now() WHERE user_id=mapping.uid;
  END LOOP;
  -- Invalidate old recovery links and refresh sessions after changing credentials.
  DELETE FROM auth.one_time_tokens WHERE user_id=ANY(original_ids);
  DELETE FROM auth.refresh_tokens WHERE user_id=ANY(SELECT unnest(original_ids||duplicate_ids)::text);
  DELETE FROM auth.sessions WHERE user_id=ANY(original_ids);
END;
$replace$;
