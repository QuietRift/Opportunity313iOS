# Native account signup

The iOS login screen opens Parent signup through **Create a parent account**. The Other account types menu opens Provider / Organization or Young adult (18–24) signup. The shared form retains Opportunity313's navy/orange branding and uses the existing Supabase authentication and account routing.

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

- Xcode's complete unit target: 32 tests in 6 suites passed, including 7 intercepted-HTTP auth tests and 4 signup model tests.
- Auth fixtures cover confirmation-required and immediate-session responses, confirmed sign-in role claim, provider routing, existing-role precedence, denied privileged preference, unconfirmed preference, and failed role claim/retry. They use an isolated mock HTTP transport and no live signup requests.
- Final unsigned Release build for generic iPhone passed. Simulator Debug build passed.
- Four relevant UI checks passed across the final targeted runs: Parent validation/password visibility, Provider menu routing, signup opening, and startup reaching sign-in. They use an isolated iPhone simulator and fixture text; they never submit an actual signup. Earlier fixture gestures were corrected after exposing a stale Provider sheet selection, which was fixed with item-based presentation.

Real email delivery, a real-account confirmation/sign-in round trip, signed archive, physical-device behavior, and TestFlight upload remain unverified. This change does not upload a build to App Store Connect.
