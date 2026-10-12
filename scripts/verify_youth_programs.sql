-- Read-only checks under the shared parent/youth database role.
begin;
set local role authenticated;
do $$
begin
    if (select count(*) from public.organizations
        where id in ('31310000-0000-4000-8000-000000000005',
                     '31310000-0000-4000-8000-000000000006')
          and verification_status = 'verified' and not is_demo) <> 2 then
        raise exception 'Expected two visible verified providers';
    end if;
    if not exists (select 1 from public.opportunities
        where id = '31320000-0000-4000-8000-000000000013'
          and organization_id = '31310000-0000-4000-8000-000000000005'
          and status = 'published' and grade_min = 1 and grade_max = 8
          and age_min is null and age_max is null and is_free and cost_cents = 0
          and starts_at at time zone 'America/Detroit' = timestamp '2026-11-07 13:00:00'
          and ends_at at time zone 'America/Detroit' = timestamp '2026-12-12 16:00:00'
          and registration_method = 'external_url'
          and registration_url = 'https://docs.google.com/forms/d/e/1FAIpQLSeDzdTye6Fa2KVrGAbobJW6QX_hvs8AkPawUfwzVF2umqqUJA/viewform') then
        raise exception 'Apple program is missing or does not match reviewed facts';
    end if;
    if not exists (select 1 from public.opportunities
        where id = '31320000-0000-4000-8000-000000000014'
          and organization_id = '31310000-0000-4000-8000-000000000006'
          and status = 'published' and age_min = 14 and age_max = 24
          and starts_at is null and deadline is null
          and registration_method = 'registration_closed'
          and registration_url = 'https://gdyt.org/youth') then
        raise exception 'Closed GDYT resource is not visible with reviewed eligibility';
    end if;
end $$;
rollback;
