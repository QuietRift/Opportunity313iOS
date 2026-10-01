# Profile expansion — September 22, 2026

Expanded the parent AccountView Profile tab with an account avatar, actual account name/email, role label, name editing, managed youth cards, add/edit actions, family saves, activity, notifications, help, account settings, and sign out. Existing tabs, colors, card styling, child access controls, recommendations, and appearance choices remain available. Provider/admin accounts retain role-appropriate content.

ParentChildDetailView now includes all requested detail labels and an Edit sheet backed by the existing youth profile and guardian access rules. Guardian relationships are fetched from the existing relationship table. Edits refresh managed youth lists. Optional grade clearing explicitly encodes null.

Data boundaries: the backend stores age bands rather than exact ages. ZIP/neighborhood, transportation, and separate category preferences are not currently stored; recommendations continue using existing interests. School links are now stored separately as pending or school-admin-verified associations for student ticket eligibility; see `docs/TICKETING.md`. Activity and Notifications provide honest informational states because application tracking and notification history are not implemented. Account editing updates the display name in existing auth metadata; email is displayed read-only.

Validation:
- iOS Simulator build succeeded for both simulator architectures in the staging copy.
- Seven native unit tests passed, including the new optional-grade encoding test.
- Rolled-back database check passed: an active guardian can update a linked youth; an unrelated account cannot. No test changes persisted.
- git diff --check passed.
- Final build from the original Desktop project succeeded (arm64 and x86_64 simulator). Xcode only reported the standard skipped App Intents metadata notice. Log: /tmp/Opportunity313ProfileFinal.log.
- Interactive signed-in UI flows and display-name persistence were not exercised. The SDK's auth update signature was checked against its official documentation.

Test result bundle: /tmp/Opportunity313ProfileBuild/Logs/Test/Test-Opportunity313-2026.09.22_10-10-07--0400.xcresult
