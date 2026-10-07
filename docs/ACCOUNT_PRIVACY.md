# Account privacy and child access

## Revoke access versus permanently delete

Parents have two separate actions in a child's profile:

| Action | Child access | Profile and work | Recovery |
| --- | --- | --- | --- |
| Revoke Child Access | Current code/email login and sessions stop working | Parent retains the profile, interests, changes, saves, school verification and tickets | Create a new access code for the same profile and identity |
| Delete Child Profile | Child access stops | Profile, saves, verification and assigned tickets are permanently removed for all linked guardians | Cannot be undone; requires typing `DELETE` |

Revocation bans the child Auth identity, removes its sessions and youth role, invalidates the code, and detaches its sign-in from the profile. The identity/credential mapping is retained so restoration preserves ticket ownership and history. Generating a new code reuses that identity. The parent still sees the child under Children. Revoked and deleted accounts' old JWTs are denied on REST/RPC requests, including ticket endpoints. Previously downloaded/offline data cannot be recalled from a device.

Permanent deletion is a separate authenticated server operation. It checks the caller's active guardian relationship. Only dedicated app-generated child identities are erased with a child profile; an independent email account is suspended rather than deleting an unrelated login. Permanent credential deletion does not queue the misleading "profile kept" revocation notice.

## Delete My Account

Profile → Account Settings → Delete My Account requires typing `DELETE`. The server verifies the session and always deletes that session's owner; client-supplied account IDs are ignored. The app only signs out and removes the owner's cached ticket tokens/holds after confirmed server success. Failures remain visible and allow retry.

Auth hard deletion invokes transactional application cleanup. A parent's solely managed children are deleted; a child with another active guardian remains with that guardian. Shared organization data remains with other active members, with the departing member's matching contact details cleared. A sole-member organization's profile details and submitted opportunities are erased; a placeholder organization/event records may remain for other event participants. User-owned storage objects are removed through the Storage API before Auth deletion. Storage cleanup and Apple revocation are external operations, so an error can require retry even if an earlier cleanup step succeeded.

The server's REST/RPC account guard checks live account existence and ban status. It does not claim to invalidate previously downloaded files or every open Realtime/Storage connection. Current child access does not offer uploads or Realtime subscriptions.

### Apple setup before real Apple-account testing

Linked Apple accounts require fresh native Apple confirmation and server-side Apple authorization revocation before deletion. Set server-only `APPLE_CLIENT_ID` and `APPLE_CLIENT_SECRET` in Supabase Edge Function secrets. For the native app, the client ID must match the registered bundle ID (`com.Kevin.Opportunity313`) and the Apple code's audience. Generate the client-secret JWT using the owner's Apple team/key details and renew it before expiration. Never commit the signing key or client secret, or embed either in an app/website.

Deletion refuses to claim success when Apple setup, code exchange, account matching or revocation fails. Apple sign-in remains disabled pending owner account setup. Real Apple authorization/revocation, a signed archive and TestFlight upload have not been verified here.

## Email preferences and unsubscribe

Profile → Account Settings → Email Preferences lets a user turn optional updates off/on. Preferences are protected by owner-only RLS. Welcome, child-profile, organization and submission updates respect this preference. Child access creation/replacement and revocation are security notices and continue, as do requested authentication/password-reset messages.

Each queued email template includes a signed unsubscribe/preferences link, without an access code or email address in the token. Opening the link only checks it; opting out requires a POST. Optional mail also includes RFC 8058 one-click headers. The public endpoint only permits changing optional-email preferences, uses an HMAC capability, and rejects forged tokens/deleted accounts. The branded web page removes the token from its address after reading it and sends no referrer. Users can re-enable updates in the app.

Before sending: publish `website/unsubscribe/` at `https://www.opportunity313.com/unsubscribe/`, or set server-only `EMAIL_PUBLIC_BASE_URL` to the intended HTTPS site. The email worker checks that page before claiming queue items, so a missing page does not consume delivery attempts. Complete Resend DNS/SMTP/secrets setup and real inbox delivery tests, review stale queued mail, then enable the existing email cron. Email and push schedulers remain inactive; no real mail was sent by these tests.

## Verification (2026-10-07)

- Native unit suite: 49 tests across six suites passed, including confirmed-only deletion, error handling, preferences persistence and owner-scoped ticket cleanup.
- Unsigned iPhone Release build passed. Native account settings, email preferences, account deletion, revocation wording and the separate child deletion sheet were inspected in Device Hub. The child deletion button starts disabled. Automated UI taps failed to navigate simulator tabs, so no passing automated end-to-end UI test is claimed; the attempted harness was removed. Complete device/VoiceOver/Dynamic Type testing before release.
- Offline regressions: `test_child_access.mjs`, `test_transactional_email.mjs`, `test_privacy_functions.mjs` passed. Browser fixtures checked unsubscribe confirmation/error/retry and 390/1440px layouts without live preference writes.
- Hosted rollback suites: `test_account_privacy_rollback.sql` and `test_email_queue_rollback.sql` passed, including RLS, token forgery, shared guardian retention, deletion cleanup and email behavior.
- Disposable live QA: create/redeem/replace/revoke/restore retained the same child identity and edited interests; revoked JWTs were denied. GET unsubscribe did not change preferences, one-click POST opted out, and app preferences re-enabled updates. Permanent child deletion and parent deletion with a sole-child cascade passed; stale sessions/tokens were denied. Fixture accounts/profiles were removed and checked absent. No real accounts were deleted.

`scripts/test_child_access_live.mjs` and `scripts/test_privacy_deletion_live.mjs` require a specially created disposable `.invalid` QA fixture stored outside the repository with restrictive permissions. The deletion script permanently destroys that fixture; never use real account credentials. SQL rollback scripts are nonpersistent test transactions. Security advisors introduced no new warnings; older project function-permission warnings and disabled leaked-password protection remain separate existing findings.
