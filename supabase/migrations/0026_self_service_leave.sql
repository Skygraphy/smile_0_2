-- Self-service "leave a channel" / "leave a group" -- until now only an
-- admin/owner could remove someone; a member had no way to remove
-- themselves at all. Both are additive DELETE policies alongside the
-- existing admin/owner-scoped "for all" ones (Postgres ORs permissive
-- policies together per command), so nothing about admin/owner management
-- changes.

-- Deliberately excludes a group-derived row (via_group_id is not null):
-- that row is owned by reconcile_channel_group_access
-- (migrations/0020_groups.sql) and would just silently reappear the next
-- time anything about the group changes, exactly like a direct delete by
-- an admin would (see channel_members_screen.dart's existing UI guard for
-- the same reason). Leaving that access has to go through leaving the
-- group instead.
create policy channel_memberships_self_leave on channel_memberships
  for delete using (user_id = auth.uid() and via_group_id is null);

-- No such restriction needed here -- leaving a group is exactly what
-- should trigger reconcile_channel_group_access to clean up whatever
-- channel access that group granted, via the existing AFTER DELETE
-- trigger on this table (fires the same way regardless of who deleted
-- the row).
create policy group_members_self_leave on group_members
  for delete using (user_id = auth.uid());
