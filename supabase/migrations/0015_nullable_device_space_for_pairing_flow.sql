-- Phase 2: pairing direction per concept doc sect. 14 is Frame-displays /
-- Phone-scans (not the reverse -- smile_0_1's kiosk had its own code-entry
-- screen). A device therefore requests its own pairing code before it
-- belongs to any Space, and a Space Owner's phone later claims that code
-- for their Space -- so devices.space_id and pairing_codes.space_id must
-- both be settable only once claimed, not at row-creation time.

alter table devices alter column space_id drop not null;
alter table devices add constraint devices_space_required_once_active
  check (space_id is not null or lifecycle_state in ('unpaired', 'pairing'));

alter table pairing_codes alter column space_id drop not null;
alter table pairing_codes add constraint pairing_codes_device_provisioning_has_device
  check (code_type <> 'device_provisioning' or device_id is not null);

-- Hardens is_own_device: rotating a device's refresh secret (not just
-- revoking the device outright) now also invalidates any still-unexpired
-- access token minted under the old credential_version, not only future
-- refresh attempts -- closing the gap the smile_0_1 prototype's 5-year,
-- no-rotation device JWT left open.
create or replace function is_own_device(check_device_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select coalesce((auth.jwt() ->> 'device_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid) = check_device_id
    and exists (
      select 1 from devices d
      where d.id = check_device_id and d.lifecycle_state in ('active', 'offline')
    )
    and coalesce((auth.jwt() ->> 'credential_version')::int, -1) = coalesce(
      (select refresh_secret_version from device_credentials where device_id = check_device_id), -2
    );
$$;
