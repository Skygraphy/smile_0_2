-- Which album a Frame is showing right now (decided 2026-10-09): until now
-- only the tablet knew (its local Personal-Mode pick), so the app could
-- neither show it nor change it. The server now keeps it:
--   * the app (the Space's managers) sets it -- "Jetzt zeigen";
--   * get-media-batch stores what the Frame actually shows, including a
--     switch made on the Frame itself;
--   * the frames row change wakes the Frame (sync_notify), which then
--     syncs the newly chosen album.
-- The last choice wins, wherever it was made.

alter table frames
  add column current_channel_id uuid references channels(id) on delete set null;

-- Only an album that is actually on this Frame. Service-role writes
-- (get-media-batch) check the visible list themselves.
create or replace function check_frame_current_channel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.current_channel_id is not null
     and new.current_channel_id is distinct from old.current_channel_id
     and not exists (select 1 from frame_channels
                     where frame_id = new.id and channel_id = new.current_channel_id) then
    raise exception 'frame_not_assigned_to_channel' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists check_frame_current_channel on frames;
create trigger check_frame_current_channel
  before update of current_channel_id on frames
  for each row execute function check_frame_current_channel();

-- Taking the shown album off the Frame: back to the default (first album).
create or replace function clear_frame_current_channel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update frames set current_channel_id = null
   where id = old.frame_id and current_channel_id = old.channel_id;
  return old;
end;
$$;

drop trigger if exists clear_frame_current_channel on frame_channels;
create trigger clear_frame_current_channel
  after delete on frame_channels
  for each row execute function clear_frame_current_channel();

-- A switch from the app is a visible change like the others (0064): push
-- for the other managers. The Frame's own switches (service role, no
-- auth.uid()) stay silent.
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
     or new.channel_switch_enabled is distinct from old.channel_switch_enabled
     or (new.current_channel_id is distinct from old.current_channel_id and new.current_channel_id is not null) then
    perform emit_event('frame_changed', jsonb_build_object(
      'frame_id', new.id,
      'actor_id', auth.uid(),
      'old_name', old.name,
      'new_name', new.name,
      'old_state', old.lifecycle_state,
      'new_state', new.lifecycle_state,
      'video_sound', case when new.video_sound is distinct from old.video_sound then new.video_sound end,
      'channel_switch', case when new.channel_switch_enabled is distinct from old.channel_switch_enabled
                             then new.channel_switch_enabled end,
      'current_channel_id', case when new.current_channel_id is distinct from old.current_channel_id
                                 then new.current_channel_id end));
  end if;
  return new;
end;
$$;
