# Youth program additions — October 12, 2026

## Verified sources

- [Saturdays in the D youth programs](https://www.learninginthed.com/register/youth-programs/): Apple Code + Create, free, grades 1–8, Michigan Engineering Zone, 3663 Woodward Ave, Detroit, MI 48201. Saturdays November 7–December 12, 2026, 1–4 p.m. Eastern; no November 28 session.
- [Official registration form](https://docs.google.com/forms/d/e/1FAIpQLSeDzdTye6Fa2KVrGAbobJW6QX_hvs8AkPawUfwzVF2umqqUJA/viewform): title “Code + Create Youth Registration (Fall 2026)”; currently displays participant fields and Next. A configured closed-message string exists in the HTML payload but is not the rendered form state. Do not treat that unused string as current closure. No submission was made. Registration availability may change; the app uses “View Registration,” not a guaranteed-open badge.
- [GDYT youth page](https://gdyt.org/youth): explicitly says the 2026 application is closed; selection is not guaranteed.
- [GDYT home page](https://gdyt.org/): summer employment for Detroit youth ages 14–24. No future cycle dates confirmed.

## Integration

`scripts/import_apple_code_create_and_gdyt.sql` adds two providers and two linked, non-demo opportunities using the existing official-resource import pattern. Run the whole transaction. Stable IDs are insert-only on conflict to preserve later administrative edits and closure. No provider login, membership, or access permissions are created.

Apple uses grade eligibility without invented age bounds, the existing Technology category, and the direct external registration URL. Unknown deadline, capacity, transportation and accommodation details remain unset. Meals are not advertised. GDYT remains a published informational resource at the user's request despite closed enrollment. Its deadline is null because the public-feed policy excludes expired deadlines; closure is explicit in its summary, schedule and registration method. No upcoming employment dates or venue address are invented. The schema requires cost fields; GDYT is represented with zero participation cost, with no wage or stipend promise.

The new `registration_closed` method displays “Registration closed” instead of “Ongoing” and labels its external link “View Program.” Existing external registrations retain “View Registration.” Both dashboards reach the shared Discover/detail flow, with a new parent dashboard shortcut using the existing card design. Profile eligibility, saves, recommendations and RLS remain unchanged.

## Database validation

Applied to the app's existing Supabase project on October 12, 2026 after rollback verification. Running the import twice inside a rolled-back transaction preserved exactly two records. Both organizations and opportunities are visible under the existing authenticated role used by parent and youth accounts. Post-import query confirmed provider links, published status, grade/age eligibility, registration methods and URLs, and Detroit local start/end times. No schema or policy changes were required.

## iOS validation

Xcode 27 built the app and all 20 unit tests passed on the iOS 27 iPhone 17 simulator with simulator signing enabled. This includes three new tests covering closed-resource wording, unchanged external-registration behavior and grade 1–8 eligibility boundaries for both profile types. The initial unsigned run failed the existing Keychain save/read test; the signed run passed it. `scripts/verify_youth_programs.sql` passed against the live database, and the app's public REST endpoint returned both listings. `git diff --check` passed. Interactive parent/youth account navigation was not rehearsed in this task.
