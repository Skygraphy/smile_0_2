-- Fix: on_space_created (0003) unconditionally inserted auth.uid() as the
-- new Space's owner, which NOT-NULL-violates space_owners.user_id whenever
-- a space row is inserted outside a real user session (service-role Edge
-- Function, superuser/admin script, seed data) -- auth.uid() is null there.
-- Caught by a live RLS test against the hosted project (2026-09-04).
create or replace function handle_new_space()
returns trigger
language plpgsql
security definer
as $$
begin
  if auth.uid() is not null then
    insert into space_owners (space_id, user_id) values (new.id, auth.uid());
  end if;
  return new;
end;
$$;
