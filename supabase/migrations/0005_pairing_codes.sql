-- One-time pairing codes (concept doc sect. 14-15). Two scopes:
--   device_provisioning -- binds a new Smile-Frame to a Space (not a Channel,
--                          concept doc sect. 16).
--   channel_invite       -- binds a person to exactly one Channel.
-- Redemption always goes through an Edge Function using the service-role
-- key (claim-device-provisioning / claim-channel-invite), which bypasses
-- RLS entirely -- the policies in 0009 only govern who may create/list/
-- revoke codes from within the Smile app's admin screens.
create table pairing_codes (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  channel_id uuid references channels(id) on delete cascade,
  device_id uuid references devices(id) on delete cascade,
  code text not null unique,
  code_type text not null check (code_type in ('device_provisioning', 'channel_invite')),
  expires_at timestamptz not null,
  max_uses int not null default 1,
  use_count int not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (code_type <> 'channel_invite' or channel_id is not null)
);

create index idx_pairing_codes_space on pairing_codes(space_id);
create index idx_pairing_codes_channel on pairing_codes(channel_id);
