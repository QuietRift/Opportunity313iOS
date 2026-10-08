# Firebase / Resend validation — October 7, 2026

> Update: Firebase apps are now registered and all three local client files are installed. See [FIREBASE_CONNECTION.md](FIREBASE_CONNECTION.md) for the current status and configured-build verification.

## Changes made

- iOS checkout `.gitignore`: exclude Firebase client files, conventional service account
  filenames, APNs/private-key files, local environment files, Supabase CLI state and Python caches.
- Android checkout `.gitignore`: add the same configuration/secret exclusions.
- `.env.example`: empty server-only credential placeholders and production email preference URL.
- `supabase/config.toml`: preserve `verify_jwt = false` for the five already-deployed
  endpoints, each of which implements its own handler authentication.
- `scripts/check_firebase_config.py`: validate local Firebase files without logging values.
- `docs/FIREBASE_RESEND_SETUP.md` and this validation record.

Existing application code, Firebase SDK versions, Resend worker, email templates,
preferences, account-deletion flow, database migrations and user edits were preserved.
No secrets, client configuration values, remote writes, commits, pushes or provider
messages were created by this setup task. Older ChatGPT-project snapshots were not
copied over the current app.

## Passed checks

- iOS unsigned generic-device Release build with installed/cached package dependencies.
  No signed archive or physical-device push check was performed. Xcode reported the
  usual skipped App Intents metadata extraction warning.
- Android offline Debug and Release builds, including release vital lint, using the
  installed Java 21 runtime. Initial attempt with Android Studio's Java 25 failed with
  a runtime-version error; retry succeeded without changing project code.
- Android `testDebugUnitTest` task succeeded using existing cached results: 24 tests,
  zero failures/errors. The task was up-to-date, so these were not newly executed tests.
- Fresh email worker fixtures: ten templates, escaping, no child credentials in mail,
  private dispatch, missing configuration, idempotency, acceptance/retries/permanent
  failure, opt-out, security notices, unsubscribe headers and missing preference page.
- Fresh push worker fixtures: both native payloads, RSA signing with generated test
  keys, private dispatch, absent configuration, retries/permanent failure and
  suppression for unpublished/demo/expired/old events. No real messages were sent.
- Fresh existing child-access and privacy-function regression fixtures.
- Validator fixture checks: missing optional/required configs, valid three-client
  setup, wrong bundle/package, project mismatch, malformed plist/JSON and no values in output.
- TOML syntax and equality with the five deployed function JWT settings.
- Git ignore checks for client config, private environment, service-account JSON and APNs key paths;
  `git diff --check` passed.

## Live read-only findings

Supabase project `pinpurdjfbvxrwexzlre` has active `transactional-email`, `opportunity-push`,
`child-access`, `email-unsubscribe` and `delete-account` functions. Both delivery cron
jobs are inactive. Both dispatch secret names exist in Vault; their values were not
read. Both queues were empty at inspection. Both queue tables have RLS enabled and
deny SELECT to `anon` and `authenticated` roles.

All three Firebase client files are missing locally. The validator reports MISSING;
its strict `--require-config` mode correctly fails readiness. No claim is made that
provider secrets, DNS verification, SMTP or APNs are configured remotely.

## Remaining activation checks

Complete the console steps in `FIREBASE_RESEND_SETUP.md`, install the actual client
files, then rebuild with configuration present. Verify SMTP confirmation/recovery,
transactional mail and unsubscribe in real inboxes; verify FCM on physical devices
with correct signing. Inspect real provider delivery events before enabling either
queue. Firebase/Resend acceptance alone does not establish successful delivery.
