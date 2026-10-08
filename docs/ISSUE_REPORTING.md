# Report an Issue

Available to signed-in parent, child, provider, athletics, and admin accounts from Profile → Report an Issue. Profile → Help & Support → My Reports shows the user’s reports, current status, and the team’s response. An opportunity’s actions menu opens a report with its context attached. Opportunity tickets also link to a registration issue form.

Categories: app/website, account/profile, registration/ticket, opportunity information, and other. A title and description are required. The app includes its version and build; the website includes its platform. No attachments or automatic device logs are collected. The form asks users to leave out credentials, payment details, and ticket QR codes. Reports are private to the submitting account and admins; family linkage does not share report content.

Admin Dashboard → Issue Reports lists the latest 200 reports, filterable by status. Admins can move reports through Submitted, In Review, and Resolved and leave a response visible to the reporter. Resolutions require an explanation. Concurrent edits use report versions to prevent overwriting another admin’s changes. Review actions are audited privately.

Provider website: Report an issue in the workspace header opens the same reporting service, related opportunity selection, own report history, and responses. Sign in with an Organization account. The website changes ship to the existing deploy preview; the main website changes when the feature branch is merged.

Submissions use idempotent request IDs; retrying an uncertain response does not create another report. Failed requests preserve the form text. Server validation enforces length/category checks, opportunity visibility, and five new reports per ten minutes per account. Clients cannot insert or update report rows directly. Deleting the reporting account cascades its reports and audit rows. This is an in-app review workflow; it does not send email or phone alerts for report responses.

Validation: simulator build; app tests for input validation and response decoding; provider browser fixtures for failure/retry, draft retention, report history, linked context, response visibility and escaping; SQL rollback coverage for role isolation, validation, duplicate requests, admin response, stale edits, audit, rate limiting and denied anonymous/direct writes. Test reports are rolled back.
