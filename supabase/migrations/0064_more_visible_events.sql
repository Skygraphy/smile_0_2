-- "Alles komplett interaktiv", second round (found 2026-10-06: Roman got no
-- signal when Ernst added a Frame). Changes that so far only synced
-- silently now raise a server event; notify-event turns each into a
-- visible push (and a Verlauf entry) for everyone affected except the
-- person who did it. This file covers the changes the app writes directly;
-- the ones made by Edge Functions (Frame created/deleted, album assigned
-- to a Frame, photo deleted) push from those functions, which know the
-- actor.
--
-- auth.uid() is the actor. Service-role writes (heartbeats, restores) have
-- none: those are skipped -- except a Frame being paired, which the tablet
-- itself does (lifecycle pending -> active).

-- Frames: renamed, paired, revoked/reactivated, settings changed ----------
create or replace function handle_frame_changed_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_paired boolean := old.lifecycle_state = 'pending' and new.lifecycle_state = 'active';
begin
  if auth.uid() is null and not v_paired then
    return new;
  end if;
  if new.name is distinct from old.name
     or new.lifecycle_state is distinct from old.lifecycle_state
     or new.video_sound is distinct from old.video_sound
     or new.channel_switch_enabled is distinct from old.channel_switch_enabled then
    perform emit_event('frame_changed', jsonb_build_object(
      'frame_id', new.id,
      'actor_id', auth.uid(),
      'old_name', old.name,
      'new_name', new.name,
      'old_state', old.lifecycle_state,
      'new_state', new.lifecycle_state,
      'video_sound', case when new.video_sound is distinct from old.video_sound then new.video_sound end,
      'channel_switch', case when new.channel_switch_enabled is distinct from old.channel_switch_enabled
                             then new.channel_switch_enabled end));
  end if;
  return new;
end;
$$;

drop trigger if exists on_frame_changed_event on frames;
create trigger on_frame_changed_event
  after update on frames
  for each row execute function handle_frame_changed_event();

-- An album taken off a Frame (the app deletes the assignment itself; adding
-- goes through assign-frame-channel). Cascades (Frame/album gone) skip.
create or replace function handle_frame_album_removed_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and exists (select 1 from frames where id = old.frame_id)
     and exists (select 1 from channels where id = old.channel_id and deleted_at is null) then
    perform emit_event('frame_album_removed', jsonb_build_object(
      'frame_id', old.frame_id, 'channel_id', old.channel_id, 'actor_id', auth.uid()));
  end if;
  return old;
end;
$$;

drop trigger if exists on_frame_album_removed_event on frame_channels;
create trigger on_frame_album_removed_event
  after delete on frame_channels
  for each row execute function handle_frame_album_removed_event();

-- Albums: created, renamed ------------------------------------------------
create or replace function handle_album_created_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    perform emit_event('album_created', jsonb_build_object('channel_id', new.id, 'actor_id', auth.uid()));
  end if;
  return new;
end;
$$;

drop trigger if exists on_album_created_event on channels;
create trigger on_album_created_event
  after insert on channels
  for each row execute function handle_album_created_event();

create or replace function handle_album_renamed_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and new.name is distinct from old.name then
    perform emit_event('album_renamed', jsonb_build_object(
      'channel_id', new.id, 'actor_id', auth.uid(), 'old_name', old.name, 'new_name', new.name));
  end if;
  return new;
end;
$$;

drop trigger if exists on_album_renamed_event on channels;
create trigger on_album_renamed_event
  after update on channels
  for each row execute function handle_album_renamed_event();

-- Spaces: renamed ----------------------------------------------------------
create or replace function handle_space_renamed_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and new.name is distinct from old.name then
    perform emit_event('space_renamed', jsonb_build_object(
      'space_id', new.id, 'actor_id', auth.uid(), 'old_name', old.name, 'new_name', new.name));
  end if;
  return new;
end;
$$;

drop trigger if exists on_space_renamed_event on spaces;
create trigger on_space_renamed_event
  after update on spaces
  for each row execute function handle_space_renamed_event();
