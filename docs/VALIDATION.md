# Core stabilization validation — 2026-09-18

## Scope and environment

Xcode 27.0 (27A266a), Opportunity313 scheme, iPhone 18 Pro iOS 27 Simulator.
The original Git baseline was `df69e59` and had a clean working tree.
No backend schema, RLS policy or production role assignments were changed.

## Evidence

- Original MVP built successfully in Xcode before edits.
- Three native unit tests passed: parent-managed profile decoding, backend save
  payload column names, and youth/family save reset behavior.
- Two native UI tests passed: launch resolves to account/sign-in state, and
  sign-in/signup navigation prevents submission of empty credentials.
- Authenticated REST checks passed for all four supplied demo accounts: sign-in,
  expected role, and the role's core data queries. Test sessions were signed out.
- The transaction in `scripts/check_mvp_rollback.sql` passed provider submission,
  pending visibility restrictions, admin queue and publication, youth discovery,
  youth save/calendar/unsave, parent child creation/ownership, parent save/family
  calendar/unsave, unrelated-child isolation, and provider publication visibility.
  It uses the authenticated database role and JWT claims, not a bypass of RLS.
  All test writes, including organization verification, were rolled back.
- Private-key patterns and service-role JWTs were absent from tracked source.
  The existing app key is publishable. The explicitly authorized temporary credential scheme was ignored by Git and
  deleted after the native rehearsal; no password was committed.

## Stabilization changes

Account lookups now show loading/retry/error states rather than an indefinite
spinner or accidental onboarding. Auth token refresh does not unnecessarily
recreate role screens. Account changes reset shared saves, and stale requests
cannot restore old account save data. Repeated save taps are serialized.
Parent child queries explicitly scope to the current guardian. Provider Events
now shows existing opportunity schedules. Provider/admin/children/saved/calendar
fetch failures show errors. Sign-in and resend prevent duplicate requests.
Submission defaults to a future deadline and validates deadline, capacity and URL.
The project no longer defaults every data model to main-actor isolation; service
objects remain explicitly main-actor isolated. User-specific Xcode state is ignored.

## Coverage boundaries

The rollback check verifies backend writes and access control, while REST checks
verify real authentication and read paths. They do not substitute for a complete
four-role UI write rehearsal. An optional native test browses all four existing
role flows when local credentials are configured; its final status is recorded
below. Signup confirmation delivery and clicking an email link were not retested.

## Existing backend advisories

Supabase security advisors report public-callable SECURITY DEFINER functions
and disabled leaked-password protection. The inspected onboarding, managed-child,
verification and publication RPCs enforce authentication/role checks, and tested
role isolation passed. No broad backend permission changes were made in this iOS
checkpoint. Review function grants separately before public launch:
https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Final native verification

Final Product → Test run completed at 08:09 on the iPhone 18 Pro iOS 27
Simulator: six tests passed, zero skips and zero failures. The app and both test
targets compiled. The configured native rehearsal passed youth discovery/details,
saved/calendar/profile; parent managed-child details/discovery/family calendar;
provider opportunities/events/profile; and admin review queue/account. All four
accounts signed out. The Simulator password-saving prompt was dismissed rather
than saving credentials. The temporary ignored credential scheme was deleted,
and Xcode was restored to the credential-free Opportunity313 scheme.

The rehearsal exposed canceled save-load requests presenting errors and an alert
binding mutating shared published state during view updates. Canceled requests
now exit quietly and the alert uses local presentation state. The successful
rehearsal includes the calendar transitions that previously failed. Stable
accessibility identifiers identify opportunity and managed-child links.

Result bundle: `Test-MVP Validation Local-2026.09.18_08-07-12--0400.xcresult`
(local Xcode DerivedData, not committed). Native coverage browses existing data;
write paths are verified by the rollback transaction, not a complete UI write
rehearsal. No production test opportunity or child remains from validation.

The current Supabase Swift SDK emits a known initial-session behavior notice.
Its configuration was preserved; adopting the advertised upcoming session
semantics would require expiration/refresh verification and is outside this fix.
