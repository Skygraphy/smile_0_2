-- Found during manual testing of co-owners: nothing stopped a channel's own
-- home Space from ending up in channel_shares for that same channel --
-- e.g. Bergoma "sharing" Urlaub 2026 (a channel Bergoma already owns
-- outright) with itself. Not a recursion/crash risk (channel_shares is a
-- plain join table, not a hierarchy any code walks recursively) and no new
-- privilege would be granted (the home Space already has full access
-- regardless) -- but it's a nonsensical state that would show up as
-- confusing duplicate entries (e.g. list-my-channels merging the home
-- Space and the "shared" Space into one list, showing "Bergoma, Bergoma").
-- Blocked at both places `channel_share_requests.space_id` ever gets set
-- to a real value: the self-initiated 'request' direction's insert, and
-- an 'invite' direction's accept (the invitee's own choice of space_id).
drop policy channel_share_requests_insert on channel_share_requests;
create policy channel_share_requests_insert on channel_share_requests
  for insert with check (
    (direction = 'invite' and is_home_space_owner(channel_id))
    or (
      direction = 'request' and target_user_id = auth.uid() and is_space_owner(space_id)
      and space_id <> (select c.space_id from channels c where c.id = channel_id)
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
        or (is_space_owner(space_id) and space_id <> (select c.space_id from channels c where c.id = channel_id))
      )
    )
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  );
