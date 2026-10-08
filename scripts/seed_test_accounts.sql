-- Explicit developer-only fixture seed, never an automatic production migration.
-- In the SAME transaction, set app.test_account_password before running this file.
-- All six addresses must be absent. A collision aborts without changing any data.
DO $seed$
DECLARE
  fixture record;
  uid uuid;
  parent_uid uuid;
  youth_id uuid;
  org_id uuid;
  test_password text := current_setting('app.test_account_password', true);
BEGIN
  IF test_password IS NULL OR length(test_password) < 12 THEN
    RAISE EXCEPTION 'Supply app.test_account_password in the same transaction';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('opportunity313-standard-test-accounts'));
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = ANY(ARRAY[
    'parent@opportunity313.com','child1@opportunity313.com','child2@opportunity313.com',
    'provider@opportunity313.com','admin@opportunity313.com','athletics@opportunity313.com'])) THEN
    RAISE EXCEPTION 'A fixture address already exists; refusing to overwrite accounts or passwords';
  END IF;
  FOR fixture IN SELECT * FROM (VALUES
    ('parent','parent','Test Parent'),
    ('child1','youth','Test Child 1'),
    ('child2','youth','Test Child 2'),
    ('provider','provider','Test Provider'),
    ('admin','admin','Test Admin'),
    ('athletics','athletics','Test Athletics')
  ) AS fixtures(alias, app_role, display_name)
  LOOP
    uid := gen_random_uuid();
    INSERT INTO auth.users (
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      confirmation_token,recovery_token,email_change_token_new,email_change,
      raw_app_meta_data,raw_user_meta_data,is_super_admin,created_at,updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated',
      fixture.alias || '@opportunity313.com',
      extensions.crypt(test_password,extensions.gen_salt('bf',10)),now(),
      '','','','',
      jsonb_build_object('provider','email','providers',jsonb_build_array('email'),
                        'test_fixture','opportunity313-standard-2026-09-26'),
      jsonb_build_object('display_name',fixture.display_name,'full_name',fixture.display_name),
      false,now(),now()
    );
    INSERT INTO auth.identities (provider_id,user_id,identity_data,provider,created_at,updated_at)
    VALUES (uid::text,uid,jsonb_build_object('sub',uid::text,'email',fixture.alias || '@opportunity313.com',
      'email_verified',true,'phone_verified',false),'email',now(),now());
    -- handle_new_user creates public.profiles using display_name.
    INSERT INTO public.user_roles (user_id,role) VALUES (uid,fixture.app_role::public.app_role);
    IF fixture.alias = 'parent' THEN parent_uid := uid; END IF;
    IF fixture.app_role = 'youth' THEN
      -- Direct-login fixtures use the existing youth_account type. Current schema
      -- requires parent_managed.user_id IS NULL; no constraint or policy is changed.
      INSERT INTO public.youth_profiles (user_id,first_name,age_band,grade,gender,interests,account_type)
      VALUES (uid,fixture.display_name,'18–24',null,null,
        CASE WHEN fixture.alias='child1' THEN ARRAY['Technology','Arts'] ELSE ARRAY['Sports','Learning'] END,
        'youth_account') RETURNING id INTO youth_id;
      INSERT INTO public.guardian_relationships
        (guardian_user_id,youth_profile_id,relationship,status,verified_at)
      VALUES (parent_uid,youth_id,'parent','active',now());
    END IF;
    IF fixture.app_role IN ('provider','athletics') THEN
      INSERT INTO public.organizations (name,organization_type,description,contact_name,contact_email,
        verification_status,verified_at,is_demo)
      VALUES ('Opportunity313 Test ' || initcap(fixture.app_role),
        CASE WHEN fixture.app_role='provider' THEN 'community_provider'::public.organization_type
          ELSE 'athletics_host'::public.organization_type END,
        'Development test organization. Synthetic data only.',fixture.display_name,
        fixture.alias || '@opportunity313.com','verified',now(),true) RETURNING id INTO org_id;
      INSERT INTO public.org_members (organization_id,user_id,role,status)
      VALUES (org_id,uid,'owner','active');
    END IF;
  END LOOP;
END;
$seed$;
