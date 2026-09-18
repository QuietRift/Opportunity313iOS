# Requested next-phase features

User decision on 2026-09-18: fix current MVP flows first; plan the features below
for the next phase. They are not implemented in this checkpoint.

## School profiles and events

Let parents supply the child's current school, display it in youth profiles,
and prioritize that school's sports/events. Add upcoming school events to Home
only after identifying a reliable source, school identity model, publication
ownership, and moderation rules. Do not label general opportunities as school
events or imply that a saved opportunity is a confirmed registration.

## Parent–child account linking

Support either a parent invitation to the child's email or a youth request to
the parent's email. Resolve the recipient through signup/sign-in and require an
explicit guardian approval before activating the relationship. The existing
Supabase guardian_relationships architecture should remain the source of truth.

Plan secure single-use expiring invitations, recipient validation, resend and
revocation, duplicate requests, and transition from a parent-managed profile to
a linked youth account without losing saves. Email dispatch belongs on a trusted
server; no private key should enter the iOS app. Do not grant guardian access
merely because an email address was entered.

## Linked interests

Youth already edit their own interests. Once account linking exists, parents
should see the same linked youth profile, with clear ownership of interest
editing and consistent recommendations. Avoid creating a second divergent youth
profile during invitation acceptance.

## Decisions needed before implementation

- School/event data source and who may create or approve school listings.
- Required guardian consent and the age-dependent signup/approval workflow.
- Whether a parent invitation links an existing youth profile or converts a
  selected parent-managed child; rules for conflicts and duplicate identities.
- Whether email alone is sufficient notification or in-app notices are also needed.

Provider registration management remains outside the agreed MVP. The dashboard
now links to existing Opportunities, Events and Account screens.
