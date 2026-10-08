# Desktop Organization workspace

The existing `/provider/` site is now a desktop Organization workspace connected
to the same Supabase project, provider role, memberships, organization records,
and admin approval workflow as the iOS app. The live domain reported by Netlify
is `www.opportunity313.com`.

## Included

- Desktop sidebar, readable submission table, and responsive navigation/forms.
- Existing email/password sign-in plus signup with honest email-confirmation
  handling and resend. Parent, Youth, Admin, and Athletics accounts cannot enter
  the Organization workspace unless they also hold the provider role.
- Complete organization profile create/edit via the existing atomic
  `save_organization_profile` endpoint. Optional fields can be cleared; identity
  and verification remain read-only. Fields survive save failures and refresh.
- Pending, Approved, and Rejected counts, filters, search, and working details.
  Rejected uses the same verification field as the admin/iOS review flow.
- Opportunity submission always sends `pending_review`, with the signed-in
  creator and organization. Successful submissions are distinguished from a
  subsequent list-refresh failure so users are not asked to submit again.
- Paginated opportunity loading, session refresh, sign-out cleanup, recoverable
  load errors, and duplicate-click prevention. Dates are explicitly Detroit
  time even when the desktop is in another timezone.
- Clearly marked sample workspace when signed out. Sample content is never
  saved or presented as the signed-in organization's records.
- Explicit `/provider` to `/provider/` redirect and absolute asset URLs. The
  provider route stays out of search indexing and has a scoped content policy.

The existing static HTML/CSS/JavaScript stack and navy/orange Opportunity313
branding are retained. No new identity system, database tables, or backend
migration is needed. The iOS Organization migration was already applied.

## Validation — October 6, 2026

`scripts/test_provider_workspace.cjs` passed using Playwright and an isolated
Chrome session, with fixture API responses and no real sign-ins or database
writes. It covers desktop/narrow layouts, login and role restrictions, profile
create/edit/clear, error retention, approval filters/details, Pending submission,
Detroit timezone conversion, failed refresh recovery, session renewal,
pagination beyond 200 records, onboarding, and confirmation-required signup.

Rendered dashboard/profile screenshots were inspected at 1440, 1024, 720, and
390-pixel widths. Navigation, dialogs, labeled fields, visible focus states,
non-color status labels, and native form validation are implemented. This is
not a claim of formal accessibility conformance. A real-account browser
walkthrough remains untested because no login password was provided.

The design audit kept the existing navy/orange identity, replaced promotional
hero content with the working dashboard, used rows for comparable submissions,
and limited status colors and badges to actual review states. No fabricated
impact metrics, decorative gradients, or new UI framework were added.

To run the fixture suite from the repository root with Playwright installed:

```sh
node scripts/test_provider_workspace.cjs
```

If using an installed Chrome instead of Playwright's downloaded Chromium, set
`PROVIDER_TEST_BROWSER` to its executable path. `PROVIDER_TEST_ARTIFACTS` can
select an output directory for the screenshots. Runtime test artifacts should
not be committed.
