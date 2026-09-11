-- Diagnostic + real fix: group_members_self_leave (0026) let a member
-- delete their own row via RLS, but the delete matched 0 rows in practice.
-- Root cause: group_members had no SELECT policy at all for a non-owner,
-- and a DELETE issued through PostgREST evaluates against the same
-- row-visibility the SELECT policies grant before the DELETE-scoped USING
-- clause is even reached. Adding self-select (mirroring
-- channel_join_requests_select's "own row" clause from 0025) fixes the
-- self-leave delete and also lets a member read their own membership row
-- directly if ever needed.
create policy group_members_self_select on group_members
  for select using (user_id = auth.uid());
