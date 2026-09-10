-- Smile-Frame device fleet. A device is associated with a Space (not a
-- single Channel or a single User) -- concept doc sect. 16. Which channels
-- a device may display is a separate concern (channel_memberships, 0003).

create table devices (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  name text not null,
  serial_number text,
  android_id text,
  fcm_token text,
  -- Device lifecycle (concept doc sect. 33): a freshly created row starts
  -- 'unpaired'; claim-device-provisioning moves it through 'pairing' to
  -- 'active'. 'revoked'/'retired' are terminal (or near-terminal) states
  -- used for lost/stolen/decommissioned hardware.
  lifecycle_state text not null default 'unpaired'
    check (lifecycle_state in ('unpaired', 'pairing', 'active', 'offline', 'revoked', 'retired')),
  current_app_version text,
  current_policy_version int not null default 0,
  last_seen_at timestamptz,
  last_compliance_check_at timestamptz,
  last_compliance_state text
    check (last_compliance_state in ('compliant', 'drift_detected', 'repaired', 'unknown')),
  battery_level int,
  is_charging boolean,
  created_at timestamptz not null default now()
);

create index idx_devices_space on devices(space_id);

create table device_policies (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null unique references devices(id) on delete cascade,
  display_mode text not null default 'slideshow' check (display_mode in ('slideshow', 'manual')),
  slideshow_interval_seconds int not null default 8,
  compliance_check_interval_minutes int not null default 15,
  -- Personal Mode channel-switcher UI is policy-driven, never a local
  -- device setting (concept doc sect. 19-20): Assisted Mode devices keep
  -- this off.
  channel_switch_enabled boolean not null default false,
  -- Full local offline cache is the default (a Frame must keep showing all
  -- assigned media with no connectivity). Null = unlimited/no eviction.
  max_local_cache_gb numeric,
  policy_version int not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

-- Append-only compliance/telemetry history (concept doc sect. 27: device ID,
-- app version, OS version, uptime, storage, network status, last sync).
create table device_heartbeats (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  space_id uuid not null references spaces(id) on delete cascade,
  checked_at timestamptz not null default now(),
  compliance_state text not null
    check (compliance_state in ('compliant', 'drift_detected', 'repaired', 'unknown')),
  drift_details jsonb,
  app_version text,
  os_version text,
  uptime_seconds bigint,
  storage_used_pct int,
  battery_level int,
  is_charging boolean,
  network_type text,
  last_sync_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_device_heartbeats_device_checked on device_heartbeats(device_id, checked_at desc);
