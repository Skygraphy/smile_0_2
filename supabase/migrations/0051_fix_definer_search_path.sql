-- Found while moving the test suite to its own project (weakness 8): NO
-- user account could be deleted -- the Auth API answered "Database error
-- deleting user" every time (145 throwaway test users had piled up on the
-- live project, and a real "delete my account" would have failed too).
--
-- Cause: handle_space_owner_removal (0037, the co-owner handover on account
-- deletion) is security definer but had no fixed search_path. Deleting via
-- the Auth API runs as supabase_auth_admin, whose search_path doesn't
-- include public, so the unqualified `spaces` / `space_co_owners` didn't
-- resolve and the whole delete aborted. The automatic handover to a
-- co-owner had therefore never worked outside a postgres-role session.
--
-- Pinning search_path on every security definer function that still lacks
-- it -- the same fix, for the four request/channel triggers of 0031/0038
-- too, before they hit the same trap from some other role.
alter function handle_space_owner_removal() set search_path = public;
alter function handle_channel_membership_request_decided() set search_path = public;
alter function handle_channel_share_request_decided() set search_path = public;
alter function handle_new_channel() set search_path = public;
alter function handle_space_co_owner_invite_decided() set search_path = public;
