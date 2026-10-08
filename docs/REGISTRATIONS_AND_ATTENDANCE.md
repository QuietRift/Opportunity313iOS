# Registrations and organization attendance

Parent and youth Home dashboards now include a **My Registrations** shortcut card, styled like the existing Tickets and family shortcuts. Bottom navigation remains unchanged. Parents see their own and actively linked children's registrations; children see only their own. Upcoming, Completed, and Cancelled filters cover in-app opportunity registrations and the existing event reservations. A family attendee picker filters opportunity registrations when more than one attendee is present.

Completed means the program has ended or attendance was recorded. The app distinguishes **Attended** from **Completed — attendance not recorded**. It does not imply attendance merely because a date has passed. Opportunity registration details show the existing ticket information and current attendance/cancellation state.

Parents may cancel family opportunity registrations before the scheduled start. Independent 18–24 youth accounts without an active guardian relationship may cancel their own. Managed children have view-only cancellation access, including legacy underage profiles labeled `youth_account`. Cancellation retains history, invalidates ticket presentation, and frees capacity. Retrying cancellation is idempotent; re-registering creates a new ticket with a new entry code. Athletics event reservations retain their existing owner cancellation and school-check-in rules.

The organization dashboard has an **Attendees** shortcut. Organizations can also open **View Attendees** on an in-app opportunity in their Opportunities list. Each roster displays registered and cancelled totals, attendance totals, remaining spots when capacity is set, and attendee names. Mark Attended requires confirmation, records who performed the action and when, and changes the registration to Attended. Cancelled registrations cannot be marked attended; repeat attendance requests preserve the original timestamp. Providers receive no QR entry codes, auth user IDs, guardian relationships, or child contact details through the roster.

## Data and access

The existing `opportunity_tickets` records remain the source of truth. New audit columns record cancellation and attendance. Clients retain read-only table access through family RLS. My Registrations adds a server-derived cancellation permission; private mutation implementations enforce current family relationships, organization memberships, registration state, and cancellation timing. Public RPC wrappers use invoker security and authenticated-only execution. Cancellation and issuance share the opportunity-row lock so freed capacity and new registrations serialize correctly.

Applied migrations:

- `20261007223113_opportunity_registrations_and_attendance.sql`
- `20261007223303_registration_cancellation_ownership.sql`

The second migration accounts for legacy linked child profiles whose account-type label alone does not reliably identify managed children.

## Test the full journey

1. As an organization, create a free opportunity with **Accept free registration in Opportunity 313** enabled. Have an admin approve it.
2. As a parent, open the opportunity in Discover, choose a linked child, and confirm registration.
3. Open Home → My Registrations. Confirm the child's registration appears under Upcoming. Sign in as that child and verify only their own registration appears.
4. As the organization, open Home → Attendees → the opportunity. Confirm the attendee and remaining spots.
5. As the parent, cancel the registration before the start. Refresh the organization roster and confirm the spot is available and the cancellation remains in history. The child sees it under Cancelled and has no cancellation control.
6. Register the child again. As the organization, mark that new registration attended. Refresh both family accounts: it appears under Completed with **Attended** and an attendance timestamp.

Current external-registration opportunities keep their provider links. External bookings are not automatically imported into My Registrations or rosters. Notifications refresh open screens within the running app; separate devices fetch updates when the screen appears, the app becomes active, or the user pulls to refresh. This does not add remote push or realtime subscriptions, waitlists, public reviews, or automatic QR scanning for opportunity providers.

## Validation

- Simulator build passed.
- All 55 unit tests across eight suites passed in the signed simulator run.
- `scripts/test_registrations_attendance_rollback.sql` passed on the connected backend: family and child visibility, managed-child cancellation denial, parent and independent adult cancellation, released capacity, re-registration, provider isolation, safe roster fields, attendance retries and timestamps, child attendance visibility, late cancellation denial, and revoked organization membership.
- Every integration fixture and temporary profile/relationship change rolled back; no test registrations or opportunities remain.
- Added model tests for registration groups, explicit attendance versus an elapsed schedule, server-derived cancellation permission, and roster decoding with unlimited capacity.
- Security advisors reported no findings for the new functions. Existing project-wide findings remain separate; see [Supabase database advisor guidance](https://supabase.com/docs/guides/database/database-linter).
- An authenticated visual walkthrough on a physical device remains to be performed.
