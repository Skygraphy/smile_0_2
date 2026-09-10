-- Fixes a real Postgres/PostgREST RLS gotcha found via live testing:
-- `insert into spaces (...) ... returning ...` (the normal client pattern
-- for getting a newly created row's id back, e.g. supabase-dart's
-- `.insert().select()`) failed with "new row violates row-level security
-- policy for table spaces", even though the on_space_created trigger (0003,
-- guarded in 0012) does successfully grant ownership a moment later --
-- RETURNING's SELECT-policy check does not see that side effect on the
-- separate space_owners table within the same statement. Fix: track the
-- creator directly on the same row being returned, so visibility doesn't
-- depend on a write to a different table at all for this one bootstrap
-- case. Ongoing authorization still goes through space_owners everywhere
-- else (channels, devices, ...) -- this column is purely for the
-- create-and-immediately-read-it-back moment.
alter table spaces add column created_by uuid references auth.users(id) default auth.uid();

create policy spaces_select_own_creation on spaces
  for select using (created_by = auth.uid());
