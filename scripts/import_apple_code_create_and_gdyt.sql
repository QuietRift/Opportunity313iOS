-- First-party pages and Apple registration form checked 2026-10-12.
-- Run as one transaction. Stable IDs make reruns safe; existing records are
-- deliberately preserved so rerunning cannot reopen a subsequently closed program.
begin;

insert into public.organizations
    (id, name, organization_type, description, website, verification_status, verified_at, is_demo)
values
    ('31310000-0000-4000-8000-000000000005', 'Saturdays in the D', 'community_provider',
     'Youth learning programs, including Code + Create in coordination with UMCI and the Michigan Engineering Zone.',
     'https://www.learninginthed.com/register/youth-programs/', 'verified', now(), false),
    ('31310000-0000-4000-8000-000000000006', 'Grow Detroit''s Young Talent', 'community_provider',
     'Summer employment opportunities for Detroit youth ages 14–24.',
     'https://gdyt.org/youth', 'verified', now(), false)
on conflict (id) do nothing;

insert into public.opportunities
    (id, organization_id, title, summary, category, opportunity_type,
     age_min, age_max, grade_min, grade_max, gender_eligibility,
     starts_at, ends_at, schedule_note, deadline, timezone,
     cost_cents, is_free, location_name, street, city, state, postal_code,
     parent_requirements, registration_method, registration_url,
     status, verification_status, published_at, is_demo)
values
    ('31320000-0000-4000-8000-000000000013', '31310000-0000-4000-8000-000000000005',
     'Apple Code + Create',
     'A free program from Saturdays in the D, in coordination with UMCI and the Michigan Engineering Zone, for students in grades 1–8. Explore coding and digital creativity by making stories, artwork, and apps independently and in small groups while practicing digital literacy and positive digital citizenship.',
     'Technology', 'class', null, null, 1, 8, 'all',
     '2026-11-07 13:00:00 America/Detroit', '2026-12-12 16:00:00 America/Detroit',
     'Saturdays, November 7–December 12, 2026, 1–4 p.m. Eastern. No session November 28.',
     null, 'America/Detroit', 0, true,
     'Michigan Engineering Zone', '3663 Woodward Ave', 'Detroit', 'MI', '48201',
     'Complete a separate registration form for each student. The provider form collects parent/guardian information and pickup authorization.',
     'external_url', 'https://docs.google.com/forms/d/e/1FAIpQLSeDzdTye6Fa2KVrGAbobJW6QX_hvs8AkPawUfwzVF2umqqUJA/viewform',
     'published', 'verified', now(), false),
    ('31320000-0000-4000-8000-000000000014', '31310000-0000-4000-8000-000000000006',
     'Grow Detroit''s Young Talent — Summer Employment',
     '2026 registration is closed. Grow Detroit''s Young Talent offers summer employment opportunities for Detroit residents ages 14–24. Keep this resource saved and visit the official youth page for program information and future application updates. Applying does not guarantee selection.',
     'Career Readiness', 'resource', 14, 24, null, null, 'all',
     null, null, '2026 applications are closed. Future application dates have not been confirmed.',
     null, 'America/Detroit', 0, true, 'Detroit program sites', null, 'Detroit', 'MI', null,
     null, 'registration_closed', 'https://gdyt.org/youth',
     'published', 'verified', now(), false)
on conflict (id) do nothing;

commit;
