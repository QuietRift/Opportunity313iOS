# Firebase connection — October 7, 2026

Firebase project: `opportunity-313` (Opportunity 313).

The Firebase CLI is now signed in through the owner's Google authorization.
Authentication is retained in the CLI's private user configuration, outside the
repository. Temporary npm tooling was installed under `/private/tmp/op313-firebase-cli`;
no app dependencies or global Node installation were changed.

## Registered apps and installed local client configuration

| App | Bundle/package ID | Firebase app ID | Local file |
| --- | --- | --- | --- |
| iPhone | `com.Kevin.Opportunity313` | `1:889825754049:ios:91c630922d6de3956c4d40` | `Opportunity313/GoogleService-Info.plist` |
| Android production | `com.opportunity313.android` | `1:889825754049:android:8a058daa2fa3b4a16c4d40` | `../Opportunity313Android/app/src/release/google-services.json` |
| Android debug | `com.opportunity313.android.debug` | `1:889825754049:android:b26d6d7ca87a3b456c4d40` | `../Opportunity313Android/app/src/debug/google-services.json` |

Each app was created in the existing project, and its configuration downloaded
with Firebase's official CLI. All files are excluded from Git. They contain
client configuration, not a service account private key. CI and other developer
machines must receive these files securely before configured builds.

The existing Firebase Messaging integration now has real project configuration.
Supabase authentication/database/storage and existing app functionality remain in
place. The original Icon Composer artwork is also installed for the iPhone;
see `APP_ICON.md`.

## Verification

- `python3 scripts/check_firebase_config.py --require-config`: all three clients OK.
- Unsigned generic-iPhone Release build: passed. The built app includes
  `GoogleService-Info.plist`, with the expected Firebase project and bundle ID.
- Android Debug and Release builds with Google Services enabled: passed.
- Android unit-test task executed successfully; 24 tests, zero failures/errors.
- Firebase client files remain ignored by Git.

## Required to activate actual push delivery

1. Firebase Cloud Messaging HTTP v1 was verified enabled in the console. No API enablement change was necessary.
2. The console currently has no development or production APNs key/certificate. Enable Push Notifications for Apple App ID `com.Kevin.Opportunity313`, refresh
   the signing profile, and upload an APNs authentication key with its Apple Key ID
   and Team ID into Firebase's Apple-app messaging settings. Enter private credentials
   directly in the provider consoles.
3. Provide a least-privileged FCM sending service account for this same project.
   Store the complete JSON only in Supabase Edge Function secrets as
   `FIREBASE_SERVICE_ACCOUNT_JSON`; it must never be bundled with the app or committed.
4. Verify explicit opt-in and delivery on a signed physical iPhone and a
   Google Play-enabled Android device, including foreground/background, tap-through
   and opt-out. A successful build is not proof of push delivery.
5. Review the queue, then enable the existing `op313-opportunity-push` cron job only
   after those delivery checks. This setup has not enabled the job or sent a push.

The earlier missing-client-file findings in `FIREBASE_RESEND_VALIDATION.md` describe
an earlier inspection. This record supersedes those findings. The remaining console
steps in `FIREBASE_RESEND_SETUP.md` still apply to provider credentials and delivery.
