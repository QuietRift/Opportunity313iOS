# Native account signup

The iOS login screen opens Parent signup through **Create a parent account**. The Other account types menu opens Provider / Organization or Young adult (18–24) signup. The shared form retains Opportunity313's navy/orange branding and uses the existing Supabase authentication and account routing. Apple and Google options are implemented in the native sign-in and signup screens; see [provider setup and activation status](SOCIAL_SIGNIN.md).

## Behavior

- Collect the adult's name, email, password, and matching password confirmation. The form trims name/email, requires a nonblank name and valid email, and requires at least eight password characters. Password visibility and keyboard Next navigation are supported.
- Parent is the default. Children under 18 continue to use parent-managed profiles and private access codes. Young adult signup requires an 18–24 age confirmation.
- Send `display_name`, `full_name`, and `signup_account_type` as signup metadata. Never store passwords locally.
- When email confirmation is required, show confirmation/resend instructions and return to sign-in. An immediate authenticated response uses existing session routing.
- After a confirmed user signs in, preserve any existing backend role. Only a user without a role can request the selected public onboarding role through the existing authenticated `claim_onboarding_role` RPC. Admin/staff are not signup choices; authorization remains in backend roles and policies.
- Parent enters the Parent dashboard and adds children from the Children tab. Provider enters the existing organization setup/dashboard; submitted opportunities continue to require admin approval. Young adult enters existing profile setup.
- An account-setup error can retry through existing account recovery without submitting signup again. Existing accounts without signup preference retain manual role selection.

## Interface review

The form keeps the existing navy/orange identity, system fonts, left-aligned labels, and familiar SF Symbols. Inputs remain grouped in one form rather than separate cards. The header identifies the chosen account; help explains parent-managed children and admin approval rather than making promotional claims. Errors include text, loading prevents duplicate requests, and failed requests retain input. The scrollable layout accommodates the keyboard. Simulator screenshots were inspected; formal accessibility conformance and all Dynamic Type sizes were not audited.

## Verification

- Final unsigned generic-iPhone Release build passed. The generated Info.plist retains the opt-in Firebase settings and includes the Google OAuth callback scheme.
- All 45 unit tests in 6 suites passed with normal simulator signing, including 20 intercepted-HTTP authentication tests and 4 signup model tests. No real signup, email or OAuth login occurs in those fixtures.
- Auth fixtures cover email confirmation, immediate session, role preservation/claim/retry, public-role restrictions, child-code retry, password recovery, Google PKCE and onboarding, Apple nonce/name exchange, cancellations, failed responses, age gating and provider availability.
- Both final native signup UI checks passed: full Parent form validation/password visibility and Provider menu routing. Both social options are present. Screenshots were inspected; no account was submitted. An initial UI gesture targeted a partly visible confirmation field and was corrected to require the entire field to be visible before typing. An earlier separate UI result bundle completed normally; the final combined and separate UI runs reported all cases passing, then stalled collecting results and were stopped.

Real email delivery, real Apple/Google sign-in, physical-device behavior, signed archive, and TestFlight upload remain unverified. The Apple/Google providers are currently disabled pending the owner's account setup. This change does not upload a build to App Store Connect.
