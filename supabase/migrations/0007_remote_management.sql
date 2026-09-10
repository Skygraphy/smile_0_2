-- Remote device management (concept doc sect. 28). Command set is
-- deliberately narrow -- Screen Pinning (not Device Owner) means there is
-- no remote reboot and no hard restriction enforcement, only what the app
-- itself can do while running (see plan's "Bewusste Abweichungen").
create table remote_commands (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  space_id uuid not null references spaces(id) on delete cascade,
  command_type text not null
    check (command_type in ('refresh_policy', 'clear_media_cache', 'restart_app', 'force_update')),
  payload jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'delivered', 'acknowledged', 'completed', 'failed', 'expired')),
  requested_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  delivered_at timestamptz,
  completed_at timestamptz,
  result_detail jsonb,
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index idx_remote_commands_device_status on remote_commands(device_id, status);

-- Independent versioning per app (Smile and Smile-Frame are now both
-- Flutter apps, but still shipped/updated separately).
create table app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('smile', 'smile_frame')),
  version_name text not null,
  version_code int not null,
  apk_storage_path text,
  release_notes text,
  rollout_status text not null default 'draft'
    check (rollout_status in ('draft', 'staged', 'production', 'rolled_back')),
  created_at timestamptz not null default now(),
  unique (platform, version_code)
);
