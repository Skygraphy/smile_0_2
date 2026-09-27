-- Regression from 0037_space_co_owners.sql, found when the Deno test suite
-- (supabase/functions/_tests/) started failing on every Space creation:
-- spaces_select became `is_space_owner(id) or is_staff()`, and
-- is_space_owner() is a STABLE function that looks the row up in `spaces`
-- itself -- which can't see a row inserted by the very same statement. So
-- any INSERT ... RETURNING (PostgREST's `Prefer: return=representation`,
-- supabase-dart's `.insert().select()`) failed with "new row violates
-- row-level security policy". smile-app's own create-Space call happens not
-- to read the row back, so it never showed up in the app.
--
-- The direct column check covers the founder (the only one who can ever
-- insert a Space) without a lookup; is_space_owner() still covers
-- co-owners for ordinary reads.
drop policy spaces_select on spaces;
create policy spaces_select on spaces
  for select using (owner_id = auth.uid() or is_space_owner(id) or is_staff());
