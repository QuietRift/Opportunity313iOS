# Firebase and Resend setup

> Update: Firebase apps are now registered and all three local client files are installed. See [FIREBASE_CONNECTION.md](FIREBASE_CONNECTION.md) for the current status and configured-build verification.

Inspected October 7, 2026. The current source is `Opportunity313iOS` in the
`Opportunity313` checkout, with Android in sibling `Opportunity313Android`.
The ChatGPT project contains older update snapshots; do not copy those over this checkout.

## Architecture and scope

Supabase remains the account and database authority, including roles, parent-managed
child access, school verification, provider review, tickets and account deletion.
Existing storage/assets remain unchanged. No requirement in the current app calls
for a second Firebase Auth, Firestore or Firebase Storage backend. Migrating those
services would require a separate data/identity migration and security-rule design.

Firebase Messaging is already integrated on iPhone and Android, with explicit opt-in
to the public `published_opportunities` topic. Resend is already used by the private
`transactional-email` worker, with templates, idempotency, retries, email preferences
and account-deletion compatibility. Resend SMTP also supplies Supabase Auth mail.
Google sign-in continues through Supabase and has separate OAuth configuration.

This setup change adds `.env.example`, a secret-safe local client validator,
`supabase/config.toml` preserving all five existing deployed function auth settings,
and Git exclusions in both native projects. It does not replace app code, schema,
workers or existing user changes. Firebase client configuration is public at runtime,
but excluded from Git here to meet the project's configuration policy.

## Configuration inventory

| Value/file | Where it belongs | Purpose |
| --- | --- | --- |
| `Opportunity313/GoogleService-Info.plist` | Local iOS app folder, included in app target | Firebase client for `com.Kevin.Opportunity313` |
| `app/src/debug/google-services.json` | Local Android project | Firebase client for `com.opportunity313.android.debug` |
| `app/src/release/google-services.json` | Local Android project | Firebase client for `com.opportunity313.android` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Supabase Edge Function secrets only | Complete single-line service account JSON for the same Firebase project |
| `RESEND_API_KEY` | Supabase Edge Function secrets only | Resend sending credential for verified domain |
| `EMAIL_FROM` | Supabase Edge Function secrets only | Verified sender, e.g. `Opportunity313 <notifications@opportunity313.com>` after verification |
| `EMAIL_PUBLIC_BASE_URL` | Supabase Edge Function secrets | `https://www.opportunity313.com`; must serve the working `/unsubscribe/` page |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Supplied by hosted Supabase runtime | Private worker database access; never client variables |
| APNs `.p8`, Key ID and Team ID | Firebase Console Apple messaging settings | Apple push transport |
| Resend SMTP credential | Supabase Auth SMTP settings | Signup confirmation, resend, password recovery |

The `.env.example` is documentation, not automatically loaded by native apps or hosted
workers. Do not paste credentials in chat, command arguments or source files. Enter
them directly in the provider secret settings. Private local `.env` files and keys are
ignored, but do not add secrets under arbitrary filenames. Dispatch credentials
`op313_email_worker_secret` and `op313_push_worker_secret` already exist in Vault;
do not regenerate them or expose their values.

## Firebase Console steps

1. Create/select the Opportunity313-owned Firebase project. Register the three exact
   app IDs above in that same project and download their corresponding client files.
   Never rename a production Android config to debug: debug has a different package.
2. Put files in the listed locations. Xcode uses a synchronized app folder; confirm
   `GoogleService-Info.plist` is in the built app resources. Android's Google Services
   plugin is already conditionally installed. Supply both variant files when building
   both variants; once the plugin is active a variant without matching config fails.
3. Enable the Apple App ID's Push Notifications capability, refresh signing profiles,
   and upload the APNs authentication key to Firebase with the correct key/team IDs.
   Existing app entitlements select development for Debug and production for Release.
4. Enable the Firebase Cloud Messaging API (HTTP v1). Create/select a sending service
   account with the Firebase Cloud Messaging API Admin role (`roles/firebasecloudmessaging.admin`)
   scoped to this project. Store its private JSON only as `FIREBASE_SERVICE_ACCOUNT_JSON`
   in the Supabase project `pinpurdjfbvxrwexzlre`. The current worker uses the JSON's
   `project_id` as its send target, so it must match all three client files.
5. Run `python3 scripts/check_firebase_config.py --require-config` from the iOS checkout.
   It checks parseability, required fields, bundle/package IDs and a shared project,
   without printing any values. Without `--require-config`, absent configuration is
   reported but tolerated for builds that intentionally have alerts unavailable.

Reference: [Apple setup](https://firebase.google.com/docs/cloud-messaging/ios/get-started),
[Android setup](https://firebase.google.com/docs/cloud-messaging/android/get-started),
[HTTP v1 authorization](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## Resend and Supabase Console steps

1. Add and verify an Opportunity313 sending domain in Resend. Apply only the exact DNS
   records supplied by Resend; preserve existing website and mailbox records.
2. Set `RESEND_API_KEY`, `EMAIL_FROM`, and `EMAIL_PUBLIC_BASE_URL` in Supabase Edge Function
   secrets. Use the verified domain for the From address; a sending identity is not an inbox.
3. Configure Supabase Authentication's custom SMTP: host `smtp.resend.com`, port `465`,
   username `resend`, password a Resend API key, and the verified sender email/name.
   Apply existing `supabase/email-templates/confirm-signup.html` and `reset-password.html`.
   Preserve `{{ .Token }}` in recovery mail for the native code-entry flow. Keep the
   production Site URL and existing OAuth callback allowlist.
4. Confirm the existing website `/unsubscribe/` page and deployed `email-unsubscribe`
   function work. The worker deliberately returns 503 before claiming messages if
   the page is missing. Keep the current preference-aware worker; older snapshots lack it.
5. If supporting Apple Hide My Email, register the actual outbound sender/domain with
   Apple Private Email Relay. Verify replies have a monitored destination if advertised.

Reference: [Resend Supabase SMTP](https://resend.com/docs/send-with-supabase-smtp),
[Supabase function configuration](https://supabase.com/docs/guides/functions/function-configuration).

## Controlled activation

Both existing workers are deployed with custom handler authentication. `verify_jwt = false`
in config preserves that routing; the Vault-backed worker header checks still reject
unauthorized calls. No worker redeployment or database migration is needed merely to
set provider secrets. Deploy only reviewed functions if source changes are made later.

Both `op313-transactional-emails` and `op313-opportunity-push` were confirmed inactive
on October 7. Keep them inactive while reviewing queued rows for stale/test recipients.
Dispatching a worker processes a batch, not just your test event. Use a controlled test
project or reviewed queues and approved inboxes/devices for delivery checks.

Verify signup, resend, recovery, welcome, provider review and email opt-out in real
inboxes. Verify push opt-in, foreground/background/cold start, tap-through and opt-out
on a signed physical iPhone and a Google Play-enabled Android device. Confirm an
unpublished/demo/expired opportunity does not broadcast. Resend/FCM acceptance is not
proof of delivery; inspect provider events and the recipient inbox/device.

After successful checks, enable each reviewed queue separately in Supabase SQL Editor:

```sql
select cron.alter_job(job_id := (select jobid from cron.job
  where jobname = 'op313-transactional-emails'), active := true);
select cron.alter_job(job_id := (select jobid from cron.job
  where jobname = 'op313-opportunity-push'), active := true);
```

To pause delivery use the same statements with `active := false`. This does not recall
already accepted messages. Review failures before requeueing; old accepted emails may
be outside Resend's idempotency window.

## Verification for this setup change

See `FIREBASE_RESEND_VALIDATION.md` for the actual checks run and remaining limits.
Local config validation cannot verify server credentials, APNs signing, DNS or delivery.
