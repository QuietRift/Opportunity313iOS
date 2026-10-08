# Opportunity313 test accounts

These accounts are in the existing Supabase project `pinpurdjfbvxrwexzlre`.
They are confirmed sign-in identities, not real email inboxes. All six use the
shared development password supplied in the task. The password is absent from
source, app code, test schemes, and this document.

| Email | Role | Profile / destination |
| --- | --- | --- |
| parent@opportunity313.com | parent | Original Parent account; Children lists Kevin and Sarai |
| child1@opportunity313.com | youth | Original Kevin profile, age 9–12, grade 6 |
| child2@opportunity313.com | youth | Existing Sarai profile, age 9–12, grade 6 |
| provider@opportunity313.com | provider | Original provider and organization |
| admin@opportunity313.com | admin | Original admin account |
| athletics@opportunity313.com | athletics | Verified Opportunity313 Test Athletics demo organization |

The four original personal-email Auth users were renamed to Parent, Child1,
Provider, and Admin, preserving their account IDs and linked data. Child2 and
Athletics were added. Duplicate test identities created during the initial seed
were removed after checking for attached business records. A live database scan
of text and JSON fields found zero matches for the four original personal email
addresses. Historical platform logs and backups were not changed. The system's
internal `access.opportunity313.invalid` child-access identity remains.

## Child profiles

Child1 is the original Kevin profile. Child2 now opens the **original Sarai
profile**, rather than the disposable Test Child 2 profile, which had no saved
activity and was removed. Kevin and Sarai each have an active guardian link to
the same original Parent account. Sarai's name, age band, grade, interests,
existing profile ID, and family relationship were preserved.

Sarai's profile type changed from `parent_managed` to `youth_account` so the
existing email-login flow can find her profile. This matches Kevin's test setup
and is a development exception to the under-18 access-code model.

Parents always see **Revoke Child Access**, including for email-linked children. After
confirmation, revocation suspends that child's login, removes its youth role,
and unlinks it from the youth profile. The profile becomes parent-managed;
its ID, family links, saved opportunities, and history remain. A parent can then
create a new access code. Email Auth identities are retained (banned), not deleted.
Generated-code identities are also retained, banned and disconnected. A new code restores the same identity and profile; revocation never deletes the child’s changes. Only the separate Delete Child Profile confirmation removes the profile and its data.
Access-code generation remains blocked while an email account is linked.

The October 2 update does not itself revoke either test login. Only confirming
Revoke Access in the app does so. Run `node scripts/test_child_access.mjs` for
mocked handler regressions; these do not modify test users.

## Sign-in recovery

The app now verifies an Auth user before showing role onboarding when a cached
session has no visible role. A session from a duplicate account removed during
cleanup is cleared locally and the app returns to Sign in. Onboarding also has
“Use a different account” for manual recovery. The updated app was built and
installed on the affected Xcode simulator; it showed Sign in instead of role
selection. No global Auth settings or other-device sessions were changed.

## Verification and records

`python3 scripts/verify_test_accounts.py` prompts for the password and uses
real sign-ins to check all six roles, profile access, family links, provider
organization, athletics endpoints, and admin authorization. It signs out each
test session. `Opportunity313UITests/StandardTestAccountUITests.swift` is an
opt-in simulator test. Set `TEST_RUNNER_MVP_TEST_PASSWORD` only in the local test
process environment. It checks each role's tabs and that Child1 opens Kevin
while Child2 opens Sarai.

The source files `scripts/seed_test_accounts.sql`,
`scripts/replace_personal_account_emails.sql`, and
`scripts/link_child2_to_sarai.sql` record the three guarded, one-time backend
data changes already applied. `supabase/functions/child-access/index.ts` is the
deployed version 2 safeguard. The SQL files are not automatic migrations and
must not be rerun against this backend. No manual backend step remains.
