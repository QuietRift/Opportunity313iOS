# Parent and Provider website signup

Entry points: `/signup/`, `/signup/parent/`, `/signup/provider/`. The homepage
and provider sign-in dialog link to these screens. Static HTML/CSS/JavaScript
and the established navy/orange branding are retained.

Both flows create a login through the existing Supabase email/password API,
validate confirmation passwords, show/hide passwords, and handle required email
confirmation and resend with a cooldown. No password is persisted. Confirmation
uses the project's existing email redirect configuration; users are instructed
to return to the same screen and sign in. No new redirect allowlist, SMTP, or
email templates are introduced.

After authenticated user verification, the screen reads `user_roles` and uses
`claim_onboarding_role` only for accounts with no roles. Existing incompatible
roles are rejected. Display metadata is never used as authorization.

Parent setup saves `profiles.display_name` and optional `neighborhood`, and
updates Auth `full_name`/`display_name` for compatibility with the app. The
completion screen explains that children's profiles, saves, and deadlines
currently live in the iOS app. A Parent desktop dashboard is outside this signup
change. Existing parent sign-in can also update these profile details.

Provider setup uses `save_organization_profile` and existing organization types
and fields, with read-only verification managed by administrators. Existing
memberships go directly to `/provider/`. Membership is rechecked before create
so a retry cannot create a duplicate organization. Submissions still require
admin approval. Signup and workspace use the same provider session key.

`website/shared/auth.js` shares public configuration and request handling with
the provider workspace. Sessions remain scoped to browser session storage;
parents and providers have separate session keys. Expired sessions refresh,
profile drafts survive reload/save errors, and sign-out clears local credentials
and drafts. No identity system, backend schema, dependency, or iOS source change
is added.

## Validation

- `scripts/test_signup_screens.cjs`: isolated Playwright fixtures for account
  choice, Parent/Provider signup, validation, confirmation/resend, onboarding,
  failed profile saves and reload/retry, wrong-role rejection, existing provider
  handoff, parent completion, refresh, and responsive screens.
- `scripts/test_provider_workspace.cjs`: existing workspace regression suite,
  including local session revocation and the dedicated signup entry.
- `scripts/test_signup_profiles_rollback.sql`: actual backend parent role
  idempotence, own-profile update/optional clearing, ownership isolation, and
  admin self-assignment rejection. All test writes are rolled back.
- Desktop and responsive signup renders inspected at 1440, 1024, 720, and 390px.
  No formal accessibility conformance claim. Real signup, email delivery, and
  cross-device confirmation have not been exercised with a real account.

Run browser tests with Playwright available. `PROVIDER_TEST_BROWSER` optionally
selects installed Chrome; `SIGNUP_TEST_ARTIFACTS` and `PROVIDER_TEST_ARTIFACTS`
select screenshot directories. Screenshots and credentials are not committed.
