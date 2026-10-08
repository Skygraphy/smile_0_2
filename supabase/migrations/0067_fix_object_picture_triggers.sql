-- 0066's triggers read old.cover_path on spaces/frames (and new.* on
-- DELETE), which fails at runtime ("record has no field") and broke every
-- update/delete of those rows. Read the fields through jsonb instead, which
-- works for any table and for a NULL record.
create or replace function queue_object_picture_removal()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_col text := case tg_table_name when 'channels' then 'cover_path' else 'avatar_path' end;
  v_old text := to_jsonb(old) ->> v_col;
  v_new text := case when tg_op = 'DELETE' then null else to_jsonb(new) ->> v_col end;
begin
  if v_old is not null and v_old is distinct from v_new then
    perform invoke_internal('remove-storage-files', jsonb_build_object(
      'files', jsonb_build_array(jsonb_build_object('bucket', 'avatars', 'path', v_old))));
  end if;
  return null;
end;
$$;

create or replace function handle_picture_changed_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  o jsonb := to_jsonb(old);
  n jsonb := to_jsonb(new);
  v_changed boolean;
  v_removed boolean;
begin
  if auth.uid() is null then
    return new;
  end if;
  if tg_table_name = 'channels' then
    v_changed := (n ->> 'cover_path') is distinct from (o ->> 'cover_path')
              or (n ->> 'cover_media_id') is distinct from (o ->> 'cover_media_id');
    v_removed := (n ->> 'cover_path') is null and (n ->> 'cover_media_id') is null;
  else
    v_changed := (n ->> 'avatar_path') is distinct from (o ->> 'avatar_path');
    v_removed := (n ->> 'avatar_path') is null;
  end if;
  if v_changed then
    perform emit_event('picture_changed', jsonb_build_object(
      'kind', case tg_table_name when 'spaces' then 'space' when 'channels' then 'album' else 'frame' end,
      'id', new.id, 'actor_id', auth.uid(), 'removed', v_removed));
  end if;
  return new;
end;
$$;
