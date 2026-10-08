# Family registration and opportunity updates

Parents can select themselves and several eligible linked children on Get Ticket. Selected spots are reserved atomically; a capacity or eligibility failure reserves none. Retries return existing tickets. Children still see only their own registrations and ticket.

Provider website: open an in-app opportunity from Opportunities to see attendees, record attendance, or send an update. The submission editor now offers free in-app registration; paid opportunities keep provider links. On iOS, use Attendees → opportunity → Send Opportunity Update.

Providers compose a title and message, then confirm sending. This is an announcement; it does not edit the opportunity schedule, location, or status. Registered and attended accounts and active linked guardians receive one inbox copy per account. Cancelled registrations are excluded. Provider access is checked on every send. Retrying a failed response with the same request ID does not create duplicates.

Attendees: My Registrations → Opportunity Updates, or Profile → Notifications → Opportunity Updates. Inbox works without Apple enrollment. Phone alerts use individually registered Firebase tokens and the existing scheduled worker. The lock-screen message contains no names or message details. Apple enrollment, APNs credentials, device provisioning, and notification permission are required for real iPhone delivery; no claim of end-to-end delivery has been made before that setup.

Device registrations are reassigned when another account signs in; disable and sign-out detach the token. Revoked guardians cannot read child inbox messages or receive newly claimed push deliveries. Demo opportunities create inbox fixtures only, with no phone pushes.

Validation: iOS simulator build; 55 app tests; provider browser fixture tests for attendance, announcement, in-app submissions and existing workflows; transactional SQL rollback tests for family capacity, deduplication, retry, provider authorization, child/parent inbox visibility and guardian revocation; mocked Firebase worker checks. No real test registrations, messages, or attendee notifications retained.

Server-only device/queue tables deliberately have no client policies. Existing unrelated Supabase advisor warnings are unchanged; see https://supabase.com/docs/guides/database/database-linter .
