-- Opportunity313 official-resource import
-- Verified against first-party provider pages on 2026-09-19.
-- Safe to run more than once: stable IDs are upserted.
--
-- This migration also permits starts_at to be NULL for genuinely ongoing
-- services. Provider-created events still require a date in the iOS form.

begin;

alter table public.opportunities
    alter column starts_at drop not null;

insert into public.organizations (
    id, name, organization_type, description, website,
    verification_status, verified_at, is_demo
) values
    (
        '31310000-0000-4000-8000-000000000001',
        'City of Detroit / Detroit at Work',
        'city_program',
        'City-supported employment, training, education, and career services for Detroit residents.',
        'https://detroitmi.gov/opportunities/jobs',
        'verified', now(), false
    ),
    (
        '31310000-0000-4000-8000-000000000002',
        'Detroit Public Library',
        'community_provider',
        'Detroit Public Library programs and youth services.',
        'https://detroitpubliclibrary.org',
        'verified', now(), false
    ),
    (
        '31310000-0000-4000-8000-000000000003',
        'Detroit PAL',
        'athletics_host',
        'Youth athletics and enrichment programs serving Detroit families.',
        'https://detroitpal.org',
        'verified', now(), false
    ),
    (
        '31310000-0000-4000-8000-000000000004',
        'Detroit Zoo',
        'nonprofit',
        'Education and conservation programs for children and families.',
        'https://detroitzoo.org',
        'verified', now(), false
    )
on conflict (id) do update set
    name = excluded.name,
    organization_type = excluded.organization_type,
    description = excluded.description,
    website = excluded.website,
    verification_status = 'verified',
    verified_at = now(),
    is_demo = false,
    updated_at = now();

insert into public.opportunities (
    id, organization_id, title, summary, category, opportunity_type,
    age_min, age_max, grade_min, grade_max, gender_eligibility,
    starts_at, ends_at, schedule_note, deadline, timezone,
    cost_cents, is_free, location_name, street, city, state, postal_code,
    neighborhood, transportation, meals_provided, accessibility,
    parent_requirements, registration_method, registration_url, capacity,
    status, verification_status, published_at, is_demo
) values
    (
        '31320000-0000-4000-8000-000000000001',
        '31310000-0000-4000-8000-000000000001',
        'Detroit at Work Career Services',
        'Find current jobs, training, education, workshops, and support through Detroit at Work.',
        'Career', 'resource', 18, 24, null, null, 'all',
        null, null, 'Ongoing service. Phone support is available Monday–Friday, 8 a.m.–5 p.m.', null,
        'America/Detroit', 0, true, 'Detroit at Work career centers', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact Detroit at Work for accommodation information.', null,
        'external_url', 'https://detroitmi.gov/opportunities/jobs', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000002',
        '31310000-0000-4000-8000-000000000002',
        'ProjectArt at Lincoln Branch',
        'Free weekly art classes with materials included for children at the Lincoln Branch.',
        'Arts', 'class', 4, 12, null, null, 'all',
        '2026-09-28 16:30:00-04', null,
        'Mondays, 4:30–5:30 p.m., from late September 2026 through May 2027.', null,
        'America/Detroit', 0, true, 'Detroit Public Library — Lincoln Branch', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact the library for accommodation information.',
        'A parent or guardian handles registration for younger participants.',
        'external_url', 'https://detroitpubliclibrary.org/events/event/1998456588453', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000003',
        '31310000-0000-4000-8000-000000000002',
        'ProjectArt Teens at Lincoln Branch',
        'Free weekly art classes with materials included for teens.',
        'Arts', 'class', 13, 18, null, null, 'all',
        null, null, 'Saturdays, 2–3 p.m., from late September 2026 through May 2027.', null,
        'America/Detroit', 0, true, 'Detroit Public Library — Lincoln Branch', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact the library for accommodation information.', null,
        'external_url', 'https://detroitpubliclibrary.org/news/projectart-2026', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000004',
        '31310000-0000-4000-8000-000000000002',
        'ProjectArt at Duffield Branch',
        'Free weekly art classes with materials included for children.',
        'Arts', 'class', 4, 12, null, null, 'all',
        null, null, 'Thursdays, 5–6 p.m., from late September 2026 through May 2027.', null,
        'America/Detroit', 0, true, 'Detroit Public Library — Duffield Branch', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact the library for accommodation information.',
        'A parent or guardian handles registration for younger participants.',
        'external_url', 'https://detroitpubliclibrary.org/news/projectart-2026', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000005',
        '31310000-0000-4000-8000-000000000002',
        'HYPE Teen Center and Teen Card',
        'Teen-focused library access, activities, and resources through Detroit Public Library HYPE.',
        'Education', 'resource', 13, 18, null, null, 'all',
        null, null, 'Ongoing teen service at the Main Library. Check the official page for current activities.', null,
        'America/Detroit', 0, true, 'Detroit Public Library — Main Library', null,
        'Detroit', 'MI', null, 'Midtown', null, false,
        'Contact the library for accommodation information.', null,
        'external_url', 'https://detroitpubliclibrary.org/services/hype', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000006',
        '31310000-0000-4000-8000-000000000003',
        'Little Sluggers Fall T-Ball Clinic',
        'A fall T-ball clinic for young players through Detroit PAL.',
        'Sports', 'clinic', 4, 8, null, null, 'all',
        null, null, 'September 14–October 12, 2026. Provider notes that dates and fees may change.', null,
        'America/Detroit', 3500, false, 'Detroit PAL program site', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact Detroit PAL for accommodation information.',
        'A parent or guardian completes registration.',
        'external_url', 'https://detroitpal.org/t-ball/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000007',
        '31310000-0000-4000-8000-000000000003',
        'Detroit PAL Recreation Soccer',
        'A six-week fall recreation soccer league for Detroit-area youth.',
        'Sports', 'league', 8, 12, null, null, 'all',
        null, null, 'Six-week season during September–October 2026. Confirm team schedule after registration.', null,
        'America/Detroit', 4000, false, 'Detroit PAL soccer sites', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact Detroit PAL for accommodation information.',
        'A parent or guardian completes registration.',
        'external_url', 'https://detroitpal.org/soccer/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000008',
        '31310000-0000-4000-8000-000000000003',
        'Detroit PAL Girls Recreation Soccer',
        'A six-week fall recreation soccer league for girls.',
        'Sports', 'league', 8, 12, null, null, 'girls',
        null, null, 'Six-week season during September–October 2026. Confirm team schedule after registration.', null,
        'America/Detroit', 4000, false, 'Detroit PAL soccer sites', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact Detroit PAL for accommodation information.',
        'A parent or guardian completes registration.',
        'external_url', 'https://detroitpal.org/soccer/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000009',
        '31310000-0000-4000-8000-000000000003',
        'Little Hoopers',
        'Detroit PAL introductory basketball programming for young children.',
        'Sports', 'clinic', 4, 8, null, null, 'all',
        null, null, 'Fall session runs October–November 2026. Check the official page for current registration.', null,
        'America/Detroit', 3500, false, 'Detroit PAL program site', null,
        'Detroit', 'MI', null, null, null, false,
        'Contact Detroit PAL for accommodation information.',
        'A parent or guardian completes registration.',
        'external_url', 'https://detroitpal.org/basketball/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000010',
        '31310000-0000-4000-8000-000000000004',
        'Zoo Tots: Animal Groups',
        'Caregiver-and-child classes exploring animal groups through sensory and early-learning activities.',
        'Education', 'class', 2, 3, null, null, 'all',
        null, null, 'Eight weekly 45-minute classes, September 11–October 30, 2026. One caregiver participates.', null,
        'America/Detroit', 21500, false, 'Detroit Zoo', null,
        'Royal Oak', 'MI', null, null, null, false,
        'Contact the Detroit Zoo for accommodation information.',
        'One caregiver participates. Member price is $165.',
        'external_url', 'https://detroitzoo.org/learn/youth/zoo-tots/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000011',
        '31310000-0000-4000-8000-000000000004',
        'Zoo Tots: Animal Habitats',
        'Caregiver-and-child classes exploring animal habitats through early-learning activities.',
        'Education', 'class', 3, 4, null, null, 'all',
        null, null, 'Eight weekly 60-minute classes, September 10–October 29, 2026. One caregiver participates.', null,
        'America/Detroit', 23000, false, 'Detroit Zoo', null,
        'Royal Oak', 'MI', null, null, null, false,
        'Contact the Detroit Zoo for accommodation information.',
        'One caregiver participates. Member price is $180.',
        'external_url', 'https://detroitzoo.org/learn/youth/zoo-tots/', null,
        'published', 'verified', now(), false
    ),
    (
        '31320000-0000-4000-8000-000000000012',
        '31310000-0000-4000-8000-000000000004',
        'Zoo Tots: Animals Around the World',
        'Caregiver-and-child classes using animals, maps, math, and art to explore the world.',
        'Education', 'class', 3, 4, null, null, 'all',
        null, null, 'Eight weekly 75-minute classes, September 9–October 28, 2026. One caregiver participates.', null,
        'America/Detroit', 24000, false, 'Detroit Zoo', null,
        'Royal Oak', 'MI', null, null, null, false,
        'Contact the Detroit Zoo for accommodation information.',
        'One caregiver participates. Member price is $190.',
        'external_url', 'https://detroitzoo.org/learn/youth/zoo-tots/', null,
        'published', 'verified', now(), false
    )
on conflict (id) do update set
    organization_id = excluded.organization_id,
    title = excluded.title,
    summary = excluded.summary,
    category = excluded.category,
    opportunity_type = excluded.opportunity_type,
    age_min = excluded.age_min,
    age_max = excluded.age_max,
    grade_min = excluded.grade_min,
    grade_max = excluded.grade_max,
    gender_eligibility = excluded.gender_eligibility,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    schedule_note = excluded.schedule_note,
    deadline = excluded.deadline,
    timezone = excluded.timezone,
    cost_cents = excluded.cost_cents,
    is_free = excluded.is_free,
    location_name = excluded.location_name,
    street = excluded.street,
    city = excluded.city,
    state = excluded.state,
    postal_code = excluded.postal_code,
    neighborhood = excluded.neighborhood,
    transportation = excluded.transportation,
    meals_provided = excluded.meals_provided,
    accessibility = excluded.accessibility,
    parent_requirements = excluded.parent_requirements,
    registration_method = excluded.registration_method,
    registration_url = excluded.registration_url,
    capacity = excluded.capacity,
    status = 'published',
    verification_status = 'verified',
    published_at = coalesce(public.opportunities.published_at, now()),
    is_demo = false,
    updated_at = now();

commit;
