-- Regression from 0039_prevent_self_channel_share.sql, found by the Deno
-- test suite: its "not the channel's own home Space" check read
-- `(select c.space_id from channels c where c.id = channel_id)` as the
-- caller -- but the person accepting a share invite (or sending a share
-- request) by definition can't see that channel yet (channels_select only
-- lets owners/members/already-linked Spaces see it). The subquery returned
-- NULL, `space_id <> NULL` is never true, so EVERY share invite accept and
-- EVERY share request was rejected with "new row violates row-level
-- security policy" -- in the app too, not just the tests.
--
-- Same check, but looked up through a security definer helper that
-- bypasses channels' RLS for this one column.
create or replace function channel_home_space_id(check_channel_id uuid)
returns uuid language sql security definer stable set search_path = public as $$
  select space_id from channels where id = check_channel_id;
$$;

drop policy channel_share_requests_insert on channel_share_requests;
create policy channel_share_requests_insert on channel_share_requests
  for insert with check (
    (direction = 'invite' and is_home_space_owner(channel_id))
    or (
      direction = 'request' and target_user_id = auth.uid() and is_space_owner(space_id)
      and space_id <> channel_home_space_id(channel_id)
    )
  );

drop policy channel_share_requests_decide on channel_share_requests;
create policy channel_share_requests_decide on channel_share_requests
  for update using (
    (direction = 'invite' and target_user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  )
  with check (
    (
      direction = 'invite' and target_user_id = auth.uid()
      and (
        space_id is null
        or (is_space_owner(space_id) and space_id <> channel_home_space_id(channel_id))
      )
    )
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  );
