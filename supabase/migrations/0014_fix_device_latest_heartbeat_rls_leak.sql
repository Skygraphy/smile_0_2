-- Fixes a real cross-space data leak found via live testing and flagged by
-- Supabase Studio's "Unrestricted" badge: device_latest_heartbeat (0010) was
-- a plain view, which by default runs with the view CREATOR's permissions
-- (the migration role, which bypasses RLS), not the querying user's --
-- so the device_heartbeats_select RLS policy never actually applied when
-- read through the view. Any authenticated user could see every device's
-- heartbeat across every Space on the platform. security_invoker (PG 15+)
-- makes the view evaluate with the querying role's own permissions instead,
-- so the underlying table's RLS applies exactly as it does when queried
-- directly.
drop view device_latest_heartbeat;

create view device_latest_heartbeat
with (security_invoker = true)
as
select distinct on (device_id) *
from device_heartbeats
order by device_id, checked_at desc;

grant select on device_latest_heartbeat to authenticated;
