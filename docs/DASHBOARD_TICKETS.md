# Dashboard tickets

The parent dashboard includes a Tickets shortcut card alongside Your Children, Saved Opportunities, and Upcoming Deadlines. The youth dashboard includes the same styled shortcut below its opportunity sections. Tapping the card opens My Tickets with opportunity and event tickets and Get Event Tickets. The existing bottom navigation tabs are unchanged; there is no added bottom tab or segmented dashboard switch.

Parent wallets show their own tickets and tickets assigned to children with an active guardian relationship. Child wallets show tickets assigned to that child's profile. This is enforced in Supabase, including the existing athletics event wallet and access to replacement QR codes. Cancellation of athletics reservations remains limited to the claiming account.

## Opportunity registration

The free opportunity creation form includes an optional “Accept free registration in Opportunity 313” switch. It defaults off and retains the existing provider submission and admin review process. Approved opportunities with `registration_method = in_app`, `is_free = true`, and zero cost offer Get Ticket / Register in their detail screen. Parents choose themselves or an eligible linked child; youth register their own profile. Confirming registration returns a persistent ticket and opens its details. The wallet refreshes immediately in the running app after confirmation, and fetches again when the Tickets page appears or the app becomes active. Other devices obtain the new ticket on their next fetch; this change does not add a remote push or realtime subscription.

Tickets contain opportunity name, attendee, schedule in the opportunity timezone, venue/address, status, ID, and an on-device QR code. Ongoing opportunities retain an explicit ongoing schedule rather than an invented date. Used/cancelled tickets retain those states; upcoming tickets expire at the supplied end or one day after the supplied start when there is no end.

The registration endpoint checks the signed-in role, attendee ownership/guardian relationship, publication, registration method, free price, deadline/start, age-band overlap, grade, gender, and capacity. An opportunity-row lock serializes capacity checks. Retrying returns the same non-cancelled ticket. Clients have select-only access to the new table, with family RLS; issuance is through an authenticated wrapper around a private implementation.

The current 12 published opportunities use external registration. Their links are preserved, and visiting them does not issue a ticket. No published listing was changed to in-app registration. New in-app tickets use the distinct `opportunity313:opportunity-ticket:` QR payload for provider presentation. The existing athletics staff scanner continues to handle `opportunity313:ticket:` admission codes; automated provider scanning/check-in for opportunity tickets is outside this change.

## Validation

- iOS Simulator build succeeded for the actual Desktop project.
- All 11 focused tests in `OpportunityTicketTests` and `TicketTests` passed in an ad-hoc signed simulator run. Initial unsigned runs could not access Keychain; the signed run passed those existing tests.
- `git diff --check` passed.
- New ticket model tests cover decoded attendee identity, date boundaries, terminal statuses, missing end dates, and ongoing schedules.
- `scripts/test_dashboard_tickets_rollback.sql` passed against the connected backend: parent/child/sibling visibility, duplicate retry, QR creation, external registration rejection, denied direct status writes, relationship revocation, capacity, and deadline. All fixtures rolled back.
- `scripts/test_dashboard_event_wallet_rollback.sql` passed: existing event family visibility, child isolation, cancellation visibility, own-code generation, sibling-code denial, and staff-wallet denial. All fixtures rolled back.
- Security advisors reported no finding referencing the new registration function or table. Existing project-wide findings are separate; [Supabase database advisor guidance](https://supabase.com/docs/guides/database/database-linter).

The migration `20261007142819_dashboard_opportunity_tickets.sql` is applied to the shared Supabase project. No real registrations or tickets were created by validation. An authenticated end-to-end visual registration rehearsal remains recommended before a real event.

## Registration management

See [Registrations and organization attendance](REGISTRATIONS_AND_ATTENDANCE.md) for the added My Registrations dashboard shortcuts, cancellation, and organization attendance workflow.
