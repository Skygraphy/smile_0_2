-- Closes a gap in the Phase 6b group model (0020_groups.sql): a
-- group-derived channel_memberships row (via_group_id set) is owned by
-- reconcile_channel_group_access and can be deleted by it at any time the
-- group's membership/grant changes. Until now, a channel admin could
-- manually promote/demote such a row's role (channel_members_screen.dart's
-- role menu does not restrict this, and updateMemberRole writes the table
-- directly, bypassing any app-level check) -- that role change would then
-- silently vanish the next time the group grant was revoked, since
-- reconcile deletes the row outright rather than reverting the role.
--
-- Fix: a manual role change on a group-derived row detaches it from the
-- group (via_group_id -> null), turning it into an ordinary direct
-- membership. It is then immune to reconcile's delete, at the cost of
-- losing the "via group X" provenance shown in the UI.

create or replace function trg_detach_group_membership_on_manual_role_change()
returns trigger
language plpgsql
as $$
begin
  if new.via_group_id is not null and new.role is distinct from old.role then
    new.via_group_id := null;
  end if;
  return new;
end;
$$;

create trigger on_channel_membership_manual_role_change
  before update on channel_memberships
  for each row execute function trg_detach_group_membership_on_manual_role_change();
