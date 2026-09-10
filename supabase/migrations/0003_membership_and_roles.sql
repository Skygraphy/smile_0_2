-- Channels and role assignments -- the resource-isolation boundary within a
-- Space (concept doc sect. 7-9): members of one channel need not know about,
-- and must never be able to read, another channel's content or roster in
-- the same Space.

create table channels (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  name text not null,
  kind text not null default 'family' check (kind in ('family', 'thematic')),
  created_at timestamptz not null default now()
);

create index idx_channels_space on channels(space_id);

-- Space Owner: manages a Space (create channels, assign channel admins,
-- pair devices to the Space) but is deliberately NOT an implicit channel
-- member -- reading a channel's photos still requires an explicit
-- channel_memberships row, even for the owner. This is a strict reading of
-- "no super-admin / least privilege" (concept doc sect. 9); if it proves
-- too strict in practice, this is the one row to relax.
create table space_owners (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (space_id, user_id)
);

create index idx_space_owners_user on space_owners(user_id);

-- A membership row belongs to exactly one User XOR one Device, never both,
-- and a Device row is only ever role='device'. sort_order is meaningful
-- only for device rows: the ordered list of channels a Frame may display
-- (concept doc sect. 22).
create table channel_memberships (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  device_id uuid references devices(id) on delete cascade,
  role text not null check (role in ('channel_admin', 'contributor', 'viewer', 'device')),
  sort_order int,
  created_at timestamptz not null default now(),
  check ((user_id is not null) <> (device_id is not null)),
  check ((device_id is not null) = (role = 'device')),
  unique (channel_id, user_id),
  unique (channel_id, device_id)
);

create index idx_channel_memberships_channel on channel_memberships(channel_id);
create index idx_channel_memberships_user on channel_memberships(user_id);
create index idx_channel_memberships_device on channel_memberships(device_id);

-- Self-serve Space creation (concept doc sect. 35: "Smile Space erstellen"
-- is the Space Owner's first step, done from within the Smile app -- unlike
-- the smile_0_1 prototype, where tenant creation was staff-only). Any
-- authenticated user may insert a Space (see 0009); this trigger then makes
-- them its first owner automatically, in the same transaction.
create or replace function handle_new_space()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into space_owners (space_id, user_id) values (new.id, auth.uid());
  return new;
end;
$$;

create trigger on_space_created
  after insert on spaces
  for each row execute function handle_new_space();
