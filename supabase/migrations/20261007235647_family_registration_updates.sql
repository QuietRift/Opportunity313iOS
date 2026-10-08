-- A family reservation is a single transaction: either every selected spot succeeds or none do.
create function private.native_register_family(opportunity_id_input uuid, youth_profile_ids_input uuid[], include_self_input boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb := '[]'; child uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if coalesce(cardinality(youth_profile_ids_input),0)>20 or (coalesce(cardinality(youth_profile_ids_input),0)=0 and not include_self_input) then raise exception 'Select between one and twenty attendees'; end if;
 perform 1 from public.opportunities where id=opportunity_id_input for update;
 if include_self_input then result := result || jsonb_build_array(private.native_register_opportunity(opportunity_id_input,null)); end if;
 for child in select distinct unnest(youth_profile_ids_input) loop
  if child is null then raise exception 'Invalid attendee'; end if;
  result := result || jsonb_build_array(private.native_register_opportunity(opportunity_id_input,child));
 end loop;
 return result;
end $$;
create function public.native_register_family(opportunity_id_input uuid,youth_profile_ids_input uuid[],include_self_input boolean default false)
returns jsonb language sql security invoker set search_path='' as $$ select private.native_register_family(opportunity_id_input,youth_profile_ids_input,include_self_input) $$;
revoke all on function private.native_register_family(uuid,uuid[],boolean),public.native_register_family(uuid,uuid[],boolean) from public,anon;
grant execute on function private.native_register_family(uuid,uuid[],boolean),public.native_register_family(uuid,uuid[],boolean) to authenticated;

create table public.opportunity_updates (
 id uuid primary key default gen_random_uuid(), opportunity_id uuid not null references public.opportunities on delete cascade,
 title text not null check(length(title) between 1 and 120), body text not null check(length(body) between 1 and 2000),
 created_by uuid references auth.users on delete set null, created_at timestamptz not null default now()
);
create index on public.opportunity_updates(opportunity_id);
alter table public.opportunity_updates enable row level security;
create policy provider_read_updates on public.opportunity_updates for select to authenticated using
 (exists(select 1 from public.opportunities o where o.id=opportunity_id and public.manages_organization(o.organization_id)));
grant select on public.opportunity_updates to authenticated;
create table public.registration_notifications (
 id uuid primary key default gen_random_uuid(), update_id uuid not null references public.opportunity_updates on delete cascade,
 opportunity_id uuid not null references public.opportunities on delete cascade,
 recipient_id uuid not null references auth.users on delete cascade, opportunity_name text not null,
 title text not null, body text not null, created_at timestamptz not null default now(), read_at timestamptz,
 unique(update_id,recipient_id)
);
create index on public.registration_notifications(recipient_id,created_at desc);
create index on public.registration_notifications(opportunity_id);
alter table public.registration_notifications enable row level security;
create policy own_registration_notifications on public.registration_notifications for select to authenticated using
 (recipient_id=(select auth.uid()) and exists(select 1 from public.opportunity_tickets t where t.opportunity_id=registration_notifications.opportunity_id));
grant select on public.registration_notifications to authenticated;
create function public.native_read_registration_update(notification_id_input uuid) returns void language sql security invoker set search_path='' as $$
 update public.registration_notifications set read_at=coalesce(read_at,now()) where id=notification_id_input and recipient_id=auth.uid();
$$;
grant update(read_at) on public.registration_notifications to authenticated;
create policy own_registration_notification_read on public.registration_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
revoke all on function public.native_read_registration_update(uuid) from public,anon;
grant execute on function public.native_read_registration_update(uuid) to authenticated;

create table public.registration_push_devices (
 token text primary key check(length(token) between 20 and 4096), user_id uuid not null references auth.users on delete cascade, updated_at timestamptz not null default now()
);
create index on public.registration_push_devices(user_id);
alter table public.registration_push_devices enable row level security;
create function private.native_registration_push_device(token_input text,enabled_input boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if enabled_input then insert into public.registration_push_devices(token,user_id) values(token_input,auth.uid()) on conflict(token) do update set user_id=auth.uid(),updated_at=now();
 else delete from public.registration_push_devices where token=token_input and user_id=auth.uid(); end if;
end $$;
create function public.native_registration_push_device(token_input text,enabled_input boolean) returns void language sql security invoker set search_path='' as $$ select private.native_registration_push_device(token_input,enabled_input) $$;
revoke all on function private.native_registration_push_device(text,boolean),public.native_registration_push_device(text,boolean) from public,anon;
grant execute on function private.native_registration_push_device(text,boolean),public.native_registration_push_device(text,boolean) to authenticated;
create table public.registration_push_queue (
 id uuid primary key default gen_random_uuid(),notification_id uuid not null references public.registration_notifications on delete cascade,
 token text not null references public.registration_push_devices on delete cascade, attempts int not null default 0,
 next_attempt_at timestamptz not null default now(),lease_id uuid,lease_until timestamptz,finished boolean not null default false,
 unique(notification_id,token)
);
create index on public.registration_push_queue(token);
alter table public.registration_push_queue enable row level security;
grant all on public.registration_push_queue,public.registration_push_devices,public.registration_notifications to service_role;
create function private.native_publish_opportunity_update(opportunity_id_input uuid,title_input text,body_input text,request_id_input uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare o public.opportunities%rowtype; recipients integer;
begin
 select * into o from public.opportunities where id=opportunity_id_input for update;
 if auth.uid() is null or o.id is null or not public.manages_organization(o.organization_id) then raise exception 'Organization access required'; end if;
 if o.status not in ('published','closed') then raise exception 'Updates are available after publication'; end if;
 if length(btrim(title_input)) not between 1 and 120 or length(btrim(body_input)) not between 1 and 2000 then raise exception 'Enter an update title and message'; end if;
 if exists(select 1 from public.opportunity_updates where id=request_id_input) then
  if not exists(select 1 from public.opportunity_updates where id=request_id_input and opportunity_id=o.id and created_by=auth.uid()) then raise exception 'Invalid request'; end if;
  return (select count(*)::int from public.registration_notifications where update_id=request_id_input);
 end if;
 insert into public.opportunity_updates(id,opportunity_id,title,body,created_by) values(request_id_input,o.id,btrim(title_input),btrim(body_input),auth.uid());
 insert into public.registration_notifications(update_id,opportunity_id,recipient_id,opportunity_name,title,body)
 select request_id_input,o.id,r.user_id,o.title,btrim(title_input),btrim(body_input) from (
  select t.attendee_user_id user_id from public.opportunity_tickets t where t.opportunity_id=o.id and t.status in ('upcoming','used')
  union select y.user_id from public.opportunity_tickets t join public.youth_profiles y on y.id=t.youth_profile_id where t.opportunity_id=o.id and t.status in ('upcoming','used')
  union select g.guardian_user_id from public.opportunity_tickets t join public.guardian_relationships g on g.youth_profile_id=t.youth_profile_id and g.status='active' where t.opportunity_id=o.id and t.status in ('upcoming','used')
 ) r where r.user_id is not null;
 get diagnostics recipients=row_count;
 if not o.is_demo then
 insert into public.registration_push_queue(notification_id,token)
 select n.id,d.token from public.registration_notifications n join public.registration_push_devices d on d.user_id=n.recipient_id where n.update_id=request_id_input;
 end if;
 return recipients;
end $$;
create function public.native_publish_opportunity_update(opportunity_id_input uuid,title_input text,body_input text,request_id_input uuid)
returns integer language sql security invoker set search_path='' as $$ select private.native_publish_opportunity_update(opportunity_id_input,title_input,body_input,request_id_input) $$;
revoke all on function private.native_publish_opportunity_update(uuid,text,text,uuid),public.native_publish_opportunity_update(uuid,text,text,uuid) from public,anon;
grant execute on function private.native_publish_opportunity_update(uuid,text,text,uuid),public.native_publish_opportunity_update(uuid,text,text,uuid) to authenticated;
create function public.claim_registration_push_events() returns table(id uuid,lease_id uuid,token text,notification_id uuid,opportunity_id uuid) language sql security invoker set search_path='' as $$
 with candidates as(select q.id from public.registration_push_queue q join public.registration_notifications n on n.id=q.notification_id join public.registration_push_devices d on d.token=q.token and d.user_id=n.recipient_id
 where not q.finished and q.attempts<6 and q.next_attempt_at<=now() and (q.lease_until is null or q.lease_until<now()) and n.created_at>now()-interval '24 hours'
 and exists(select 1 from public.opportunity_tickets t where t.opportunity_id=n.opportunity_id and (t.attendee_user_id=n.recipient_id or exists(select 1 from public.youth_profiles y where y.id=t.youth_profile_id and y.user_id=n.recipient_id) or exists(select 1 from public.guardian_relationships g where g.youth_profile_id=t.youth_profile_id and g.guardian_user_id=n.recipient_id and g.status='active')))
 order by q.next_attempt_at limit 20 for update of q skip locked), claimed as(update public.registration_push_queue q set lease_id=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1 from candidates c where q.id=c.id returning q.*)
 select c.id,c.lease_id,c.token,c.notification_id,n.opportunity_id from claimed c join public.registration_notifications n on n.id=c.notification_id;
$$;
create function public.finish_registration_push_event(target_id uuid,target_lease uuid,success boolean,permanent_failure boolean default false) returns void language sql security invoker set search_path='' as $$
 update public.registration_push_queue set finished=success or permanent_failure,lease_until=null,next_attempt_at=now()+interval '5 minutes' where id=target_id and lease_id=target_lease;
$$;
revoke all on function public.claim_registration_push_events(),public.finish_registration_push_event(uuid,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.claim_registration_push_events(),public.finish_registration_push_event(uuid,uuid,boolean,boolean) to service_role;
