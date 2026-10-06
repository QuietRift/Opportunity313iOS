# Organization profiles

Organization is now the user-facing account type for the existing `provider`
role. Existing accounts, `org_members`, `organizations`, submission services,
and admin approval endpoints remain authoritative. Parent, Youth, Admin, and
Athletics navigation are preserved. Admin remains an assigned role, not a
self-signup choice.

Role onboarding leads to a complete organization setup form. The profile tab
shows and edits name, type, description, website, contact name/email/phone,
service area, address, and city. A building symbol is the requested logo
placeholder. Organization ID and verification status are read-only. Account
settings and sign-out remain accessible from the profile.

The organization dashboard includes a submission action, submission counts,
profile editing, the existing opportunities list, and events. The list and
counts show Pending, Approved, and Rejected based on the same fields used by
admin review. Existing draft/paused/closed states keep their distinct labels.
Submissions still enter `pending_review`; only admin approval publishes them.
Review notes remain admin-only under the existing privacy policy.

## Backend

Migration `20261006181403_organization_profile.sql` was applied to the existing
Opportunity313 Supabase project. It adds nullable service_area/address/city
columns, restricts direct profile updates to editable columns, and adds an
atomic create/edit endpoint. The endpoint validates the authenticated provider
role and active organization membership; it never accepts verification or
identity changes. Setup retries cannot silently create duplicate memberships.
Blank optional fields clear saved values. Legacy organization rows decode
without the new optional fields.

The migration file records the exact server-assigned migration version. The
local Supabase CLI was unavailable; the connected Supabase migration tool was
used instead.

## Validation (October 6, 2026)

- Xcode 27 simulator build succeeded, for arm64 and x86_64.
- Backend rollback suite passed: create/edit/clear, membership, duplicate
  prevention, ownership isolation, self-verification denial, pending privacy,
  direct-publication denial, and admin publication.
- Existing admin-review rollback suite passed, including rejection/requeue,
  atomic approval, history, stale decisions, and public discovery visibility.
- All 21 unit tests in four suites passed on the iPhone 18 Pro simulator with
  ad hoc signing enabled, including Organization, Admin, account, and ticket
  coverage. The unsigned run failed only the existing Keychain test; signing
  resolved it without changing ticket code.
- Final build from the actual Desktop Xcode project passed.
- Organization coverage verifies legacy decoding, safe profile payloads,
  validation, and approval-status mapping.
- Backend advisory check found no finding for the new endpoint. Existing
  public security-definer RPC warnings, private-table RLS informational notices,
  and disabled leaked-password protection remain outside this change.
- Full authenticated UI walkthrough and device accessibility rehearsal have
  not been performed; no test credentials were embedded or changed.
