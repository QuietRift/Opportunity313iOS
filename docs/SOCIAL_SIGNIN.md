# Apple and Google sign-in for the iPhone app

The native sign-in and signup screens offer Apple's system **Continue with Apple** button and Google's official iOS button artwork. Email/password and parent-managed child codes remain available. Social signup does not require the email/password form to be filled out.

New Parent and Provider signups keep the chosen public account type. Existing `user_roles` always take precedence; a Provider signup cannot convert an existing Parent or Admin account. An account without a role requests onboarding through the existing authenticated `claim_onboarding_role` RPC. Organization setup and admin approval are unchanged. New users entering from the sign-in screen without a signup choice use the existing role-selection screen. Young adult signup requires the age confirmation before either social flow starts; under-18 children continue to use parent access codes.

Apple uses native AuthenticationServices authorization and Supabase's ID-token exchange. Each attempt generates 32 cryptographically random bytes, sends a SHA-256 nonce to Apple and the original nonce to Supabase for verification. The app requests email and name, saves Apple's first-authorization name if the account has none, and never replaces an existing name with an empty response. A failed name update does not discard a successful login; the user can edit their name in their profile.

Google uses Supabase's existing PKCE flow in an `ASWebAuthenticationSession`, returning to `com.kevin.opportunity313://auth/callback`. No Google client secret is embedded in the app. The system session receives the callback directly; there is no general URL handler that accepts arbitrary login sessions. Cancellation leaves the user on the form without an error. Role setup failures use the existing account-retry screen without starting another signup. If the app closes before the new role is saved, the next login can complete manual role selection.

The app checks the backend's public Auth settings when the screens open and when the app becomes active. Unconfigured providers stay disabled with an explanation; a failed settings request offers a retry. This lets service activation take effect without rebuilding the app. Provider-enabled settings are necessary but cannot prove credentials are correct; perform the real-account checks below before release.

## Current activation status

On October 6, 2026, the live project's Auth settings and dashboard showed **Apple disabled and Google disabled**, with blank Apple Client IDs/Secret Key fields and no Auth redirect URLs. No OAuth credentials or remote authentication settings were created or changed by this implementation. The owner will set up Apple Developer and Google Cloud on October 7. The buttons are implemented, but real social authentication is not live.

## Apple activation

1. In the Apple Developer account for team `QCXT66T4DU`, enable **Sign in with Apple** for the existing App ID `com.Kevin.Opportunity313` (preserve capitalization). The Xcode target and entitlement are included in this change.
2. In [Supabase Apple settings](https://supabase.com/dashboard/project/pinpurdjfbvxrwexzlre/auth/providers?provider=Apple), register that exact bundle ID as an allowed Client ID and enable Apple. The native token flow does not require an Apple web Services ID/client secret. Web-based Apple OAuth requires separate Services ID/secret setup and rotation; it is not implemented here.
3. Refresh Xcode automatic signing/provisioning for the capability and build a signed archive. Do not remove the entitlement to work around signing errors.
4. If using Hide My Email, configure Apple Private Email Relay for the actual outgoing sender once transactional email/SMTP is connected.

## Google activation

1. Use a Google Cloud project owned by Opportunity313. Configure Google Auth Platform branding, support email, privacy policy and audience. A Firebase project is not required for this login flow; Firebase Messaging remains separate.
2. Create a **Web application OAuth client** for Supabase's server callback. Add the exact authorized redirect URI: `https://pinpurdjfbvxrwexzlre.supabase.co/auth/v1/callback`.
3. Save the client ID and secret securely in [Supabase Google settings](https://supabase.com/dashboard/project/pinpurdjfbvxrwexzlre/auth/providers?provider=Google), then enable Google. Do not commit the secret, put it in the iPhone bundle, or send it in chat. Keep nonce verification enabled.
4. Add **exactly** `com.kevin.opportunity313://auth/callback` to [Supabase Auth Redirect URLs](https://supabase.com/dashboard/project/pinpurdjfbvxrwexzlre/auth/url-configuration). Keep the existing production Site URL.
5. If the Google consent app is in Testing, add the intended TestFlight testers to its test audience. Publish the consent app for the wider intended audience when ready, completing Google's applicable verification.

## Verification

- Unsigned generic-iPhone Release build passed; the generated Info.plist contains the callback URL scheme and retains Firebase's explicit opt-in settings.
- All 45 native unit tests in 6 suites passed, with normal simulator signing. New intercepted-HTTP cases cover Google PKCE exchange, Parent/Provider role requests, existing-role preservation, manual onboarding, Apple nonce/name handling, both providers' cancellation, youth age gating, disabled providers, the provider-settings request/key, and failed/unexpected responses. No real OAuth login or account creation occurs in these fixtures.
- Both native Parent and Provider signup UI checks passed. The Parent check opens both social options, validates the full email/password form and never submits an account. The Provider check opens Organization signup from the existing menu. Earlier signup screenshots were inspected. The final combined and separate UI runs reported all cases passing, then stalled collecting result bundles; those collectors were stopped. Final screenshots could not be exported. An initial test gesture targeted a partly offscreen password-confirmation field; the test now scrolls fields fully into view before typing, and the subsequent full UI suite passed.

Before TestFlight release, verify actual first-time and returning Apple and Google logins on a physical iPhone, Apple Hide My Email, Parent/Provider setup, child-code access, sign-out/relaunch, and failed/cancelled sign-in. Also verify the signed archive and upload. These live sign-ins, physical-device checks, signed archive and TestFlight upload are outstanding. This change only adds social sign-in to the native iOS app; website and Android social-login screens are not added.

References: [Supabase Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple), [Supabase Google](https://supabase.com/docs/guides/auth/social-login/auth-google), [Swift OAuth](https://supabase.com/docs/reference/swift/auth-signinwithoauth), [Swift ID-token exchange](https://supabase.com/docs/reference/swift/auth-signinwithidtoken), [Google button assets and guidelines](https://developers.google.com/identity/branding-guidelines).
