# Saturday/Sunday polish handoff

Keep the agreed MVP fixed. The next work is presentation quality: logo and app
icon, a consistent color/type system, cards/buttons/spacing/navigation,
dashboards and detailed admin review, launch experience, loading/empty/success
states, demo rehearsal and pitch screenshots. No additional roles, registration
system, tickets, messaging, AI features or new backend services are included.

## Existing feature entry points

| Role | Entry | Supporting flows |
| --- | --- | --- |
| Youth | HomeView / YouthTabView | Discover, Saved, Calendar, Profile |
| Parent | ParentHomeView / ParentTabView | Children and child detail, Discover, Family Calendar |
| Provider | ProviderHomeView / ProviderTabView | Organization setup, Opportunities, Events |
| Admin | AdminReviewView / AdminTabView | Detailed approval, Account |

Use the existing Assets catalog for identity assets. App-icon artwork is still
pending. There is no new visual system in this core stabilization checkpoint.

## Preserve while styling

- Do not render youth/provider onboarding after a failed account lookup.
- Keep retry/error feedback, form validation, and disabled duplicate actions.
- Preserve account-scoped state resets and protection against old save responses.
- Keep approval in the admin detail view and retain server-side RPC authorization.
- Preserve real submission status, provider opportunity schedules, child ownership,
  registration links, event dates and registration deadlines.
- Never put credentials in screenshots, pitch assets or source control.

## Demo rehearsal

1. Provider opens the organization, submits a valid future opportunity.
2. Admin opens the pending submission, reviews its details, approves/publishes.
3. Youth discovers it, saves/unsaves it and sees its event/deadline in Calendar.
4. Parent opens or adds a managed child, saves for that child, checks Family Calendar.
5. Sign out between roles; verify that the previous account's saves disappear.

Use a future registration deadline. Expired opportunities are hidden by the
existing public-read RLS policy, so refresh demo dates before presentation.
Do not change that policy merely to make stale demo content visible.

Use the eventual fixed slide titles as supplied; prepare copy and the seven-minute
spoken pitch around the final demonstration after visual polish.
