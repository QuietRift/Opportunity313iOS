# Opportunity313 iOS

Opportunity313 connects Detroit youth and families with reviewed opportunities.
This native SwiftUI app is the Venture313 core MVP and shares the existing
Supabase backend with the web project.

## Agreed MVP

- Email/password sign-in, signup confirmation and resend, role onboarding.
- Youth profile setup/editing, opportunity discovery and filters, saves, calendar.
- Parent-managed youth profiles, per-child saves, family calendar.
- Provider organization setup, opportunity submissions and review status.
- Admin detailed review, provider verification, approval and publication.

Provider Events displays the schedule of the organization's submitted
opportunities. It does not introduce a separate event or ticketing product.

## Run

Open `Opportunity313.xcodeproj` in Xcode 27. Select the Opportunity313 scheme
and an iOS 27 Simulator, then Build or Run. Test with Product → Test.
The deployment target and signing team retain the original project settings.
Swift dependencies are pinned by the committed `Package.resolved`.

## Architecture and configuration

SwiftUI features call main-actor service objects using `supabase-swift`.
The existing Supabase tables, RLS policies and RPC functions remain authoritative
for ownership, roles, provider verification and publication. No backend schema
changes are part of this checkpoint.

`SupabaseManager.swift` contains the existing project URL and client publishable
key. A publishable key is client configuration, not an administrator credential.
Never put service-role keys, secret keys, account passwords, or private signing
material in the app or repository. Git ignores local credentials, build data,
and Xcode user state.

## Validation

See `docs/VALIDATION.md` for evidence and remaining UI rehearsal coverage.
`python3 scripts/check_accounts.py --help` describes the read-only authenticated
account check. It prompts for a password and keeps it only in memory.

`scripts/check_mvp_rollback.sql` exercises the backend product loop under the
existing authenticated roles and rolls back all test writes. Run the whole file
as one transaction using an administrator SQL connection; never execute only
selected statements. It expects one demo account per MVP role and a provider
organization and youth profile already configured.

The optional four-role UI test reads `MVP_TEST_PASSWORD`, `MVP_YOUTH_EMAIL`,
`MVP_PARENT_EMAIL`, `MVP_PROVIDER_EMAIL`, and `MVP_ADMIN_EMAIL` from the test
runner's environment. It skips when credentials are absent. Do not commit
credential-bearing schemes or test fixtures.

## Visual polish handoff

See `docs/POLISH_HANDOFF.md`. Polish should preserve the MVP data flows and
backend architecture.
