# Admin build — September 24, 2026

Baseline: the active Desktop Xcode project, including its uncommitted profile and school ticketing work. Original user-facing views, ticketing, authentication, shared models, and project configuration are preserved. Only the admin portion of MainTabView changes.

## Audit

The previous admin tab contained a pending queue and reused OpportunityDetailView for review. It could verify a provider and publish, but made separate calls: failed publication could leave a provider verified. There was no dashboard, rejection, decision history, status management, or people oversight.

Existing server policies already allow admins to read profiles, roles, organizations, opportunities, and youth profiles. No profile access policies or role assignments were expanded. Opportunity status has no rejected enum; rejection is represented by closed + rejected verification. Publication retains the existing requirement for a start date.

## Delivered

- Dashboard with exact server counts and links to approval queues, people, and existing ticketing.
- Searchable pending, approved, rejected, and paused lists.
- Existing opportunity details plus provider context, review notes, confirmation, and the latest 50 decisions.
- Atomic approve/verify, reject with required reason, pause with reason, and return to review.
- Read-only user and youth oversight, account roles, directly linked youth profiles, and profile search.
- Role-checked endpoints, locked rows, stale-status rejection, and admin-only decision history.
- Lists paginate beyond the default API limit; dashboard counts include demo records and all published opportunities, including expired deadlines.

## Validation

Simulator build passed. Backend migration applied and rollback-only integration tests passed before and after deployment: publication rollback, required reasons, stale decisions, rejection/requeue/pause, audit history, exact counts, discovery visibility, and non-admin isolation. No real submissions were approved or rejected during testing.

All 17 Swift tests passed on the iPhone 17 simulator, including the 3 new admin tests and existing profile/ticket tests. The ticket Keychain test requires simulator signing; it passed with signing enabled. New tests cover status mapping, permitted actions, and large server counts.

The Desktop project is open in Xcode on AdminDashboardView.swift. An authenticated visual walkthrough of the admin screens was not performed; Device Hub could not be inspected through the UI tool. Build, unit tests, and backend role/transition checks are verified.

Existing Supabase advisors report pre-existing definer-function exposure and disabled leaked-password protection; these are outside this admin change. The new public endpoints are security invoker, privileged mutation lives in the private schema, anonymous execute is revoked, and both entry points check the authenticated admin role.

## Limits

Oversight is read-only; no deletion, role assignment, or profile mutation. Older decisions made through the legacy publication RPC are not backfilled. Existing published entries are treated as approved. The original publication RPC remains available for compatibility. Review notes are admin-only.

## References

[Supabase Swift RPC documentation](https://supabase.com/docs/reference/swift/rpc) was checked against the pinned 2.55.2 dependency. SQL verification: scripts/test_admin_review_rollback.sql. Applied migration: supabase/migrations/20260924175815_admin_opportunity_review.sql.
