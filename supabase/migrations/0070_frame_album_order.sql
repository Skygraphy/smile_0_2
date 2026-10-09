-- A fixed album order on every Frame (found 2026-10-09): assign-frame-channel
-- always stored sort_order 0, so all of a Frame's albums tied and "the first
-- album" -- and the order in the app's list -- depended on how the rows
-- happened to come back. Now each newly added album goes to the end, and the
-- existing ones are numbered once in the order they were added.

update frame_channels fc
   set sort_order = numbered.position
  from (
    select frame_id, channel_id,
           (row_number() over (partition by frame_id order by sort_order, created_at, channel_id) - 1)::int as position
      from frame_channels
  ) numbered
 where fc.frame_id = numbered.frame_id and fc.channel_id = numbered.channel_id;

create or replace function append_frame_album()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- 0 is the "not given" default; an explicit position is kept.
  if new.sort_order = 0 then
    select coalesce(max(sort_order) + 1, 0) into new.sort_order
      from frame_channels where frame_id = new.frame_id;
  end if;
  return new;
end;
$$;

drop trigger if exists append_frame_album on frame_channels;
create trigger append_frame_album
  before insert on frame_channels
  for each row execute function append_frame_album();
