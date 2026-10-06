-- Verlauf entries disappear once dealt with (decided 2026-10-06): tapping
-- one opens its target and removes it, a swipe removes it unopened, and
-- "Alle entfernen" clears the list. Only your own entries -- the existing
-- select policy is required too, or a DELETE silently matches nothing.
create policy user_notifications_own_delete on user_notifications
  for delete using (user_id = auth.uid());
