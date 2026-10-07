-- Deletion is not revocation: do not send a notice saying the deleted profile remains.
create or replace function private.queue_access_email() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; guardian record; event text; template text;
begin
 if tg_op='DELETE' then return old; end if;
  if tg_op='UPDATE' and new.revoked_at is not distinct from old.revoked_at and new.code_hash is not distinct from old.code_hash then return new; end if;
  target:=new.youth_profile_id;
  template:=case when new.revoked_at is null then 'child_access_created' else 'child_access_revoked' end;
  event:=template||':'||target||':'||new.updated_at;
 for guardian in select guardian_user_id from public.guardian_relationships where youth_profile_id=target and status='active' loop
  perform private.enqueue_email(guardian.guardian_user_id,event||':'||guardian.guardian_user_id,template);
 end loop;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
