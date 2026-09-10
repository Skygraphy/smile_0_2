-- Live UI updates for the Smile app (channel feed, device fleet view,
-- membership changes) via postgres_changes subscriptions.
alter publication supabase_realtime add table
  devices, device_heartbeats, remote_commands, channel_memberships, media_items, media_recipients;

-- PostgREST has no DISTINCT ON; this view gives the admin fleet screen a
-- one-row-per-device "latest heartbeat" without a client-side reduce.
create view device_latest_heartbeat as
select distinct on (device_id) *
from device_heartbeats
order by device_id, checked_at desc;

grant select on device_latest_heartbeat to authenticated;
