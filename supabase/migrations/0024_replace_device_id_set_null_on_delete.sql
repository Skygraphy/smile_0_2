-- pairing_codes.replace_device_id (0023) was added with the default NO
-- ACTION delete rule, which blocks deleting ANY device ever used as a
-- replacement target -- including long-since-retired ones -- because a
-- historical pairing_codes row still points at it. Devices are never
-- actually hard-deleted by this app today (lifecycle_state='retired' is
-- the real "gone" state), so this hasn't caused a live bug, but it's an
-- unnecessary trap for any future support/cleanup action. Switched to ON
-- DELETE SET NULL, matching how channel_memberships.via_group_id (0020)
-- already treats its own analogous provenance-link column.
alter table pairing_codes drop constraint pairing_codes_replace_device_id_fkey;
alter table pairing_codes
  add constraint pairing_codes_replace_device_id_fkey
  foreign key (replace_device_id) references devices(id) on delete set null;
