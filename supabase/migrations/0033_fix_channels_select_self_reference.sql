-- Fixes a recurrence of the exact RLS gotcha the old schema's
-- 0013_spaces_created_by.sql already discovered once: `insert into
-- channels (...) ... returning ...` (the normal client pattern, e.g.
-- supabase-dart's `.insert().select()`) failed with "new row violates
-- row-level security policy for table channels", even though the caller
-- unquestionably owns the channel's home Space (confirmed live: a plain
-- INSERT with `Prefer: return=minimal` succeeds and the row lands
-- correctly; only adding RETURNING/return=representation fails).
--
-- Root cause: `channels_select` used `can_view_channel(id)`, which calls
-- `is_home_space_owner(id)` -- and that function re-queries `channels`
-- itself (`from channels c join spaces s ... where c.id = check_channel_id`)
-- to find the row's own space_id. For the RETURNING clause's implicit
-- SELECT-policy check on a row inserted in the *same* statement, that
-- self-referential re-query hits a snapshot-visibility gap and evaluates
-- false, even though the very same space_id is sitting right there on the
-- row already. Unlike 0013's case (a *different* table populated by an
-- AFTER INSERT trigger not yet visible), this is a table querying itself.
--
-- Fix: check ownership directly against the row's own `space_id` column
-- (`is_space_owner(space_id)`, which only touches the already-existing
-- `spaces` table, no self-reference) instead of going through
-- `is_home_space_owner`/`can_view_channel` for this one policy.
-- Semantically identical for any already-committed row; only avoids the
-- create-and-immediately-read-it-back moment's timing gap.

drop policy channels_select on channels;

create policy channels_select on channels
  for select using (
    is_space_owner(space_id)
    or is_channel_member(id)
    or exists (select 1 from channel_shares cs where cs.channel_id = id and is_space_owner(cs.space_id))
    or is_staff()
  );

-- Diagnostic-only function from 0032, no longer needed.
drop function if exists debug_channels_policies();
