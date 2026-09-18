# Platform support

## Native app

The Xcode app targets iPhone and iPad on iOS/iPadOS 17 or later. It remains a
native SwiftUI app with the existing Supabase tables, policies and RPCs.
All four roles are available on iPad. Device-family configuration includes both
phone and tablet, and the tablet supports all orientations and indirect input.

Youth/parent/provider dashboards, opportunity details and calendars constrain
long-form content to readable widths while filling the surrounding window.
Graphical date pickers use a narrower centered width. Discovery search and
category controls remain outside the scrolling list on both youth and parent.

Admin review uses a NavigationSplitView: review queue alongside selected details
on a wide window, with a compact navigation experience on phones/narrow windows.
Publishing remains inside the selected detailed review and uses the same RPCs.

Minimum OS 17 is a build compatibility setting; runtime verification on each
older supported OS and physical hardware is distinct from the Simulator checks
recorded in VALIDATION.md. Android tablets require the web frontend.

## Web

SwiftUI source does not run in a web browser. The earlier project conversation
identifies a separate Lovable/React frontend. The accessible private repository
QuietRift/Opportunity313 currently describes a planning blueprint in its README,
and has no package.json at the repository root. No running web frontend or
complete source checkout was found locally in this task.

Browser support is not yet verified. Obtain the actual Lovable frontend URL or
its source repo/check-out before editing it. Keep it separate from the native
repo and reuse Supabase Auth, roles, guardian ownership, provider organization
ownership, and admin verification/publication RPCs. No service key goes in either
client. The native application must continue to work independently of the web UI.

Web validation should cover all existing role flows at tablet and desktop sizes,
with special attention to admin queue/detail selection, keyboard operation,
loading and retry, session expiry, and publication failures. Building browser
access does not authorize new school, ticketing or account-invitation features.
