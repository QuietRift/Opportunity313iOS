# Parent / Provider email and automatic child access

## Current state

Automatic child-code generation is implemented in the native Add Child flow and the live access service. The parent sees a save/share screen after adding a child, including expiry. A code failure offers retry for the existing saved profile. Replacement/revocation remain available in the child's profile. Revocation keeps the profile, edits, saves and identity; generating a new code restores that same profile. Permanent deletion is a separate action requiring typed confirmation. See [Account privacy](ACCOUNT_PRIVACY.md). Plain codes are returned once, never stored in the database or email queue, and are not emailed automatically.

The live check found and fixed an incompatible ownership constraint that rejected the synthetic child Auth identity. Dedicated child identities are now allowed on parent-managed profiles, with a server-side identity guard. Client users cannot change ownership/account type. A child can change interests, but cannot rename/re-age the profile or change guardian relationships. The access service now checks all database writes before returning a code and cleans up a newly created Auth identity if linking fails. Native code now correctly parses the ISO expiration returned by the service.

## Email coverage

| Recipient / event | Implementation | Sending status |
| --- | --- | --- |
| Parent and Provider signup confirmation / resend | Existing Supabase Auth; branded template prepared | Requires custom SMTP |
| Parent and Provider password reset | Native Forgot password, recovery OTP, new-password form; prepared reset template includes `{{ .Token }}` | Requires SMTP and applying that template |
| Parent / Provider welcome | Backend role-insert trigger | Queued; sender activation pending |
| Child profile added | Guardian insertion trigger | Queued; sender activation pending |
| Child code created/replaced / revoked | Credential lifecycle trigger; no code in email | Queued; sender activation pending |
| Provider submission Pending / Approved / Rejected / Paused | Opportunity status trigger | Queued; sender activation pending |
| Organization verified | Verification change trigger | Queued; sender activation pending |

These are operational emails, not marketing, deadline campaigns, ticket receipts, or push notifications. Users can unsubscribe from optional welcome, child-profile, organization and submission updates in the app or through the signed footer link. Child-access security notices and requested Auth/recovery messages continue. Optional messages also carry one-click unsubscribe headers; Auth templates do not use the optional-updates token. Existing internal review notes are not exposed. Provider emails go to confirmed active members' login addresses, never an arbitrary organization contact field. Child notices go to confirmed active guardians. No historical events are backfilled. Synthetic `.invalid` child identities are excluded.

The Auth Site URL was corrected from localhost to `https://www.opportunity313.com` in the Supabase dashboard. Confirmation occurs through Supabase's verification link, then users return to the app to sign in.

## Delivery setup required

Owning opportunity313.com permits domain-based addresses but does not provide an inbox or sending service by itself. Resend is the prepared automatic sender; a separate mailbox can receive support replies.

1. Create/sign in to a Resend account and add a sending domain under opportunity313.com. Verify the exact DNS records Resend supplies in the domain's DNS service. Do not replace the website's existing records or guess DNS values. Select an appropriate plan after reviewing its current limits.
2. Choose a verified From address (for example, `notifications@opportunity313.com`). Configure Supabase Authentication → SMTP Settings using Resend's current SMTP details. The owner enters the SMTP credential directly; it must not be committed or put into app code.
3. Apply `supabase/email-templates/confirm-signup.html` and `reset-password.html` in Supabase Authentication → Emails. The recovery template must include `{{ .Token }}` for the native reset-code flow. Review relevant Auth security-notification toggles after checking synthetic child password rotations do not generate undeliverable mail.
4. Publish the included branded `website/unsubscribe/` page at `https://www.opportunity313.com/unsubscribe/` (or configure `EMAIL_PUBLIC_BASE_URL` to another intended HTTPS site). The sender checks that page before claiming queued mail.
5. Set server-only Edge Function secrets `RESEND_API_KEY` and `EMAIL_FROM`. The owner enters the key in Supabase's secret settings. The deployed `transactional-email` function already has an internal scheduler credential in Vault; never expose it to a client.
6. Verify confirmation, resend, recovery, welcome, child notifications, provider submission/review and organization verification using approved real test inboxes. The sender API accepting a message is not proof of inbox delivery; inspect Resend delivery/bounce events and the inbox.
7. After delivery is verified, enable the existing `op313-transactional-emails` cron job using `cron.alter_job(job_id := (select jobid from cron.job where jobname='op313-transactional-emails'),active := true)`. It runs every two minutes. Review any queued test or stale notifications before activation.

The scheduler is deliberately inactive until sending credentials and real delivery are verified. No email service account was created, plan purchased, SMTP credentials entered, DNS changed, or real email sent during this implementation. Approved real test inboxes are still needed for delivery verification.

## Reliability / access

The service-only queue uses an event key, bounded batches, row locks, leased ownership, exponential retry, a six-attempt limit, and a stable Resend idempotency key. Missing sender configuration does not consume attempts. Permanent sender errors become failed. Success is recorded as **accepted**, not delivered. Inspect failed/expired messages operationally; delivery/bounce tracking remains in Resend. There is no claim of exactly-once inbox delivery. Terminal failures need review; do not blindly requeue old accepted emails outside the sender's idempotency window.

RLS and revoked client privileges keep queue payloads and worker functions inaccessible to anon/authenticated users. Dispatch requires the project-private Vault credential and uses custom authentication. The new queue's no-client-policy advisor INFO is intentional (deny all). Existing project warnings about older SECURITY DEFINER RPCs and leaked-password protection were also reported; those predate this change and are not a comprehensive security audit.

## Verification

- Live disposable `.invalid` QA account: create child → generate → redeem → child sign-in → only its profile visible → interests edit allowed / parent information edit denied → replace → old code rejected → revoke → old session denied → parent retains profile. Passed. Disposable user/profile removed; no codes/passwords logged and no mail sent.
- Email backend rollback suite passed: event coverage, recipient isolation, no credential payloads, service-only access, leases/backoff, inactive sender. Organization profile/admin review rollback suites also passed after the triggers were installed.
- Edge fixtures: 21 child-access regression cases passed, including failed writes and generation. Email fixtures passed for 10 templates, HTML escaping, no codes, unauthorized dispatch, missing setup, acceptance, retry/permanent failure, stable idempotency and leases. Deployed worker rejects anonymous dispatch (401).
- Native unit target: 49 tests in 6 suites passed, including child-code retry/expiry/format, password recovery, account deletion, email preferences and owner-scoped ticket cleanup checks. Account privacy rollback, disposable live revoke/restore/deletion, unsubscribe worker/browser fixtures also passed; see [Account privacy](ACCOUNT_PRIVACY.md) for coverage and UI automation limitations.
- Debug simulator build and final unsigned iPhone Release build passed.

Real mail delivery, applying SMTP/templates, email scheduler activation, native recovery against real mail, full VoiceOver/Dynamic Type checks, signed archive, and TestFlight upload remain outstanding.
