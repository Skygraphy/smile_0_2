-- ARCHITECTURE RESET. Replaces all 30 previous migrations with a schema
-- built around exactly four entities: User (auth.users), Space, Channel,
-- Frame. No data migration -- the user has an external backup and
-- explicitly asked for a clean slate in the same project. See the plan
-- under C:\Users\ernst\.claude\plans\swift-riding-snail.md for the full
-- design rationale (worked out step-by-step with a concrete Ernst/Roman/
-- Bergoma/Davidopa example) and a design-review pass that caught several
-- gaps fixed below (sort_order on frame_channels, pairing code expiry,
-- channel-creator auto-join, spaces.owner_id delete behavior, partial
-- unique indexes on the request tables).
--
-- Key departures from the schema this replaces:
--   * Space has exactly one owner (`owner_id` column, not a join table) --
--     collapsing yesterday's space_owners table, which existed to allow
--     multiple owners that turned out never to be needed.
--   * A Channel's sole administrator ("SCO" = Space/Channel Owner) is
--     always exactly its home Space's owner -- no delegated channel_admin
--     role, ever. This is deliberately less flexible than the schema being
--     replaced, whose 0030_multi_space_channels.sql let a merely-linked
--     Space's owner acquire full admin power over a shared channel via
--     is_space_owner_of_channel() -- exactly the mistake this reset avoids
--     repeating (see can_view_channel()'s comment below).
--   * Two symmetric "Facebook friend request"-style mechanisms, both
--     targeting a specific known person (their own email/account), not an
--     anonymous shareable code:
--       - channel_membership_requests (User<->Channel): posting rights.
--       - channel_share_requests (Space<->Channel): VIEW-ONLY visibility
--         for another Space, never any write/admin power.
--   * Frame creation order is reversed from the schema being replaced: the
--     Space owner creates a named Frame record first (like a Channel);
--     physical hardware later binds to it via a pairing code stored
--     directly on the frame row (no separate pairing_codes table for
--     frames -- frame_id stays stable across a hardware swap, so
--     "replace the physical unit" becomes: issue a new code + bump
--     frame_credentials.refresh_secret_version, done).
--   * No MDM: no remote_commands, no device_policies compliance/version
--     enforcement, no compliance-state history. Plain display settings
--     (display_mode, slideshow_interval_seconds, channel_switch_enabled,
--     max_local_cache_gb) are NOT MDM -- they move directly onto `frames`.
--     Basic health telemetry (last_seen_at/battery/app_version) and
--     credential rotation (real security, not policy enforcement) stay.
--   * Groups (and the whole group_channel_grants/reconcile-trigger
--     machinery) are gone -- the two request mechanisms above cover
--     everything Groups existed for, without an intermediate
--     distribution-list entity.
--   * Frames never authenticate directly against PostgREST/RLS (unlike
--     today's is_own_device()-backed device JWT, which mimics a Supabase
--     auth token). All frame-initiated reads/writes go through
--     service-role Edge Functions instead (Phase 2) -- simpler than
--     maintaining a fake-auth-JWT trick for a device that has no real
--     auth.users row, and everything a Frame actually does today already
--     goes through such a function (get-media-batch) anyway.

-- =========================================================================
-- 0. Full reset of the public schema (auth/storage/realtime schemas are
--    untouched -- users, sessions, and storage objects survive; only our
--    own application schema is wiped and rebuilt).
-- =========================================================================

drop schema public cascade;
create schema public;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, service_role;
grant all on all sequences in schema public to postgres, service_role;
grant all on all routines in schema public to postgres, service_role;
alter default privileges for role postgres in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on routines to postgres, anon, authenticated, service_role;

create extension if not exists "pgcrypto";

-- The only storage.objects policy that referenced anything in the public
-- schema (the now-gone `groups` table + is_staff()) -- must be dropped
-- explicitly since storage.objects lives outside the public schema and is
-- therefore untouched by the drop above; left in place it would error on
-- every avatar access attempt. avatars_public_read/avatars_user_write have
-- no public-schema dependency and are left completely alone.
drop policy if exists avatars_group_owner_write on storage.objects;

-- =========================================================================
-- 1. Core tables
-- =========================================================================

create table spaces (
  id uuid primary key default gen_random_uuid(),
  -- Restrict, not cascade: an owner's account being deleted must never
  -- silently take their whole Space (and everyone else's photos in
  -- channels shared into it) down with it. Reassigning/cleaning up a
  -- Space ahead of an account deletion is a deliberate staff action, not
  -- an automatic side effect.
  owner_id uuid not null references auth.users(id) on delete restrict default auth.uid(),
  name text not null,
  created_at timestamptz not null default now()
);

create index idx_spaces_owner on spaces(owner_id);

create table channels (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create index idx_channels_space on channels(space_id);

-- Posting rights. Flat membership, no roles -- only the home Space's owner
-- (the SCO) can ever manage this list; there is no delegated admin role to
-- distinguish with a role column any more.
create table channel_members (
  channel_id uuid not null references channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create index idx_channel_members_user on channel_members(user_id);

-- View-only Space<->Channel link. Deliberately its own table, never
-- conflated with channel_members -- a linked Space's owner gets read
-- access and nothing else, ever (see can_view_channel() and the RLS
-- policies below).
create table channel_shares (
  channel_id uuid not null references channels(id) on delete cascade,
  space_id uuid not null references spaces(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (channel_id, space_id)
);

create index idx_channel_shares_space on channel_shares(space_id);

-- =========================================================================
-- 2. Connection requests -- one shape, two tables, both "Facebook friend
--    request" style: whoever did NOT initiate decides accept/decline.
-- =========================================================================

create table channel_membership_requests (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  -- 'invite': the channel's SCO started it, targeting user_id -- only
  -- user_id may accept/decline.
  -- 'request': user_id started it themselves -- only the channel's SCO
  -- may accept/decline.
  direction text not null check (direction in ('invite', 'request')),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz
);

create index idx_channel_membership_requests_channel on channel_membership_requests(channel_id);
create index idx_channel_membership_requests_user on channel_membership_requests(user_id);
-- Only one open request per (channel, person) at a time -- accepted/
-- declined history is kept, not overwritten, so this is a *partial* index.
create unique index uq_channel_membership_requests_pending
  on channel_membership_requests(channel_id, user_id) where status = 'pending';

create table channel_share_requests (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  -- The other party's identity. For 'request', this is simply the
  -- requesting Space's owner (space_id is known immediately). For
  -- 'invite', the channel's SCO invites a *person* (not a specific Space
  -- of theirs, which the SCO has no way to know the name of) -- space_id
  -- stays null until that person accepts and picks which of their own
  -- Spaces to link.
  target_user_id uuid not null references auth.users(id) on delete cascade,
  space_id uuid references spaces(id) on delete cascade,
  direction text not null check (direction in ('invite', 'request')),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  check (direction = 'invite' or space_id is not null)
);

create index idx_channel_share_requests_channel on channel_share_requests(channel_id);
create index idx_channel_share_requests_target on channel_share_requests(target_user_id);
create unique index uq_channel_share_requests_pending_invite
  on channel_share_requests(channel_id, target_user_id) where status = 'pending' and direction = 'invite';
create unique index uq_channel_share_requests_pending_request
  on channel_share_requests(channel_id, space_id) where status = 'pending' and direction = 'request';

-- =========================================================================
-- 3. Frames
-- =========================================================================

create table frames (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  name text not null,
  -- 'pending': record created, hardware not bound yet. 'active': paired
  -- and in use. 'revoked': manually deactivated. No 'offline' state --
  -- staleness is derived from last_seen_at, not stored.
  lifecycle_state text not null default 'pending' check (lifecycle_state in ('pending', 'active', 'revoked')),
  pairing_code text unique,
  pairing_code_expires_at timestamptz,
  paired_at timestamptz,
  last_seen_at timestamptz,
  battery_level int,
  is_charging boolean,
  current_app_version text,
  -- Plain display settings -- not MDM/compliance, just how this Frame
  -- shows its assigned channels.
  display_mode text not null default 'slideshow' check (display_mode in ('slideshow', 'manual')),
  slideshow_interval_seconds int not null default 8,
  channel_switch_enabled boolean not null default false,
  max_local_cache_gb numeric,
  created_at timestamptz not null default now()
);

create index idx_frames_space on frames(space_id);

-- Rotating refresh-credential store (unchanged security mechanic from the
-- schema being replaced) -- never exposed to any client role, only
-- service-role Edge Functions touch this.
create table frame_credentials (
  frame_id uuid primary key references frames(id) on delete cascade,
  refresh_secret_hash text not null,
  refresh_secret_version int not null default 1,
  access_token_ttl_seconds int not null default 3600,
  created_at timestamptz not null default now(),
  rotated_at timestamptz,
  revoked_at timestamptz
);

-- Which channels a Frame is assigned to display, and in what order.
-- sort_order matters for the Frame's own channel-switcher UI and for
-- picking a sensible default channel to show first.
create table frame_channels (
  frame_id uuid not null references frames(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  primary key (frame_id, channel_id)
);

create index idx_frame_channels_channel on frame_channels(channel_id);

-- =========================================================================
-- 4. Media (channel-scoped, content and pipeline unchanged from the
--    schema being replaced -- only the device_id->frame_id rename)
-- =========================================================================

create table media_items (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  media_type text not null check (media_type in ('photo', 'video')),
  storage_path_original text not null,
  storage_path_display text,
  storage_path_thumbnail text,
  mime_type text,
  duration_seconds numeric,
  width int,
  height int,
  file_size_bytes bigint,
  processing_status text not null default 'uploaded' check (processing_status in ('uploaded', 'processing', 'ready', 'failed')),
  caption text,
  preview_data_url text check (preview_data_url is null or length(preview_data_url) <= 20000),
  created_at timestamptz not null default now()
);

create index idx_media_items_channel on media_items(channel_id);
create index idx_media_items_sender on media_items(sender_id);
create index idx_media_items_channel_created_id on media_items(channel_id, created_at desc, id desc);

-- Personal "hide for me" -- unaffected by this reset, same shape as before.
create table media_item_hides (
  media_item_id uuid not null references media_items(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (media_item_id, user_id)
);

create table media_recipients (
  id uuid primary key default gen_random_uuid(),
  media_item_id uuid not null references media_items(id) on delete cascade,
  frame_id uuid not null references frames(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  delivered_at timestamptz,
  viewed_at timestamptz,
  sort_order bigint not null default (extract(epoch from now()) * 1000)::bigint,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  unique (media_item_id, frame_id)
);

create index idx_media_recipients_frame_sort on media_recipients(frame_id, sort_order) where hidden_at is null;

-- =========================================================================
-- 5. Profiles, push tokens, staff, app releases -- unchanged
-- =========================================================================

create table profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_path text,
  updated_at timestamptz not null default now()
);

create table user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

create index idx_user_push_tokens_user on user_push_tokens(user_id);

create table staff_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('support', 'ops_admin')),
  created_at timestamptz not null default now(),
  unique (user_id)
);

create table app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('smile', 'smile_frame')),
  version_name text not null,
  version_code int not null,
  apk_storage_path text,
  release_notes text,
  rollout_status text not null default 'draft' check (rollout_status in ('draft', 'staged', 'production', 'rolled_back')),
  created_at timestamptz not null default now(),
  unique (platform, version_code)
);

-- =========================================================================
-- 6. Storage buckets (idempotent -- buckets already exist from before the
--    reset since storage lives outside the public schema, but declaring
--    them here keeps this migration self-contained/reproducible)
-- =========================================================================

insert into storage.buckets (id, name, public)
values
  ('media-originals', 'media-originals', false),
  ('media-display', 'media-display', false),
  ('media-thumbnails', 'media-thumbnails', false),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- =========================================================================
-- 7. RLS helper functions
-- =========================================================================

create or replace function is_staff()
returns boolean language sql security definer stable as $$
  select exists (select 1 from staff_members where user_id = auth.uid());
$$;

create or replace function is_space_owner(check_space_id uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from spaces where id = check_space_id and owner_id = auth.uid());
$$;

-- The ONLY source of write/admin power over a channel. Deliberately never
-- also true for a merely-linked (channel_shares) Space -- see the header
-- comment for why this distinction is the whole point of this reset.
create or replace function is_home_space_owner(check_channel_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from channels c join spaces s on s.id = c.space_id
    where c.id = check_channel_id and s.owner_id = auth.uid()
  );
$$;

create or replace function is_channel_member(check_channel_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from channel_members where channel_id = check_channel_id and user_id = auth.uid()
  );
$$;

-- Read-only visibility: the SCO, a posting member, OR the owner of a
-- Space this channel has been shared into. Used for channels_select and
-- media_items_select -- never for anything that writes.
create or replace function can_view_channel(check_channel_id uuid)
returns boolean language sql security definer stable as $$
  select
    is_home_space_owner(check_channel_id)
    or is_channel_member(check_channel_id)
    or exists (
      select 1 from channel_shares cs where cs.channel_id = check_channel_id and is_space_owner(cs.space_id)
    )
    or is_staff();
$$;

-- =========================================================================
-- 8. Triggers
-- =========================================================================

-- The SCO can post in their own channel immediately -- no self-invite
-- needed. Guarded against auth.uid() being null (a service-role insert,
-- e.g. from a seed/test script) same as the schema being replaced did.
create or replace function handle_new_channel()
returns trigger language plpgsql security definer as $$
begin
  if auth.uid() is not null then
    insert into channel_members (channel_id, user_id) values (new.id, auth.uid())
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_channel_created
  after insert on channels
  for each row execute function handle_new_channel();

-- Materializes an accepted request into the real relationship. This is
-- the *only* place channel_members/channel_shares rows get created from
-- a request -- accepting always goes through flipping status here,
-- whether that update came from a plain RLS-governed client call (the
-- decider already knows every value needed) or, for a share *invite*,
-- from the accepting person supplying which of their own Spaces to link
-- (space_id) in the same update.
create or replace function handle_channel_membership_request_decided()
returns trigger language plpgsql security definer as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    insert into channel_members (channel_id, user_id) values (new.channel_id, new.user_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_channel_membership_request_decided
  after update on channel_membership_requests
  for each row when (new.status is distinct from old.status)
  execute function handle_channel_membership_request_decided();

create or replace function handle_channel_share_request_decided()
returns trigger language plpgsql security definer as $$
begin
  if new.status = 'accepted' and old.status = 'pending' and new.space_id is not null then
    insert into channel_shares (channel_id, space_id) values (new.channel_id, new.space_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_channel_share_request_decided
  after update on channel_share_requests
  for each row when (new.status is distinct from old.status)
  execute function handle_channel_share_request_decided();

-- =========================================================================
-- 9. RLS policies
-- =========================================================================

alter table spaces enable row level security;

create policy spaces_select on spaces
  for select using (owner_id = auth.uid() or is_staff());
create policy spaces_insert on spaces
  for insert with check (owner_id = auth.uid());
create policy spaces_owner_update on spaces
  for update using (owner_id = auth.uid() or is_staff())
  with check (owner_id = auth.uid() or is_staff());
create policy spaces_staff_delete on spaces
  for delete using (is_staff());

alter table staff_members enable row level security;

create policy staff_members_staff_only on staff_members
  for all using (is_staff()) with check (is_staff());

alter table channels enable row level security;

create policy channels_select on channels
  for select using (can_view_channel(id));
create policy channels_owner_insert on channels
  for insert with check (is_space_owner(space_id));
create policy channels_owner_update on channels
  for update using (is_home_space_owner(id)) with check (is_home_space_owner(id));
create policy channels_owner_delete on channels
  for delete using (is_home_space_owner(id) or is_staff());

alter table channel_members enable row level security;

create policy channel_members_select on channel_members
  for select using (user_id = auth.uid() or is_home_space_owner(channel_id) or is_staff());
create policy channel_members_owner_write on channel_members
  for all using (is_home_space_owner(channel_id) or is_staff())
  with check (is_home_space_owner(channel_id) or is_staff());
-- Self-service leave: a member may always remove their own row.
create policy channel_members_self_delete on channel_members
  for delete using (user_id = auth.uid());

alter table channel_shares enable row level security;

create policy channel_shares_select on channel_shares
  for select using (is_home_space_owner(channel_id) or is_space_owner(space_id) or is_staff());
-- Writes happen via the request-decided triggers (security definer, bypass
-- RLS) or staff tooling -- no direct client insert policy needed.
create policy channel_shares_staff_insert on channel_shares
  for insert with check (is_staff());
-- The linked Space's owner can ALWAYS unilaterally revoke -- deliberately
-- no SCO fallback here, so the channel's own SCO can never block or
-- override the other side's ability to walk away.
create policy channel_shares_owner_delete on channel_shares
  for delete using (is_space_owner(space_id) or is_staff());

alter table channel_membership_requests enable row level security;

create policy channel_membership_requests_select on channel_membership_requests
  for select using (user_id = auth.uid() or is_home_space_owner(channel_id) or is_staff());
create policy channel_membership_requests_insert on channel_membership_requests
  for insert with check (
    (direction = 'invite' and is_home_space_owner(channel_id))
    or (direction = 'request' and user_id = auth.uid())
  );
-- Deciding: an invite is decided by the invitee; a request is decided by
-- the channel's SCO. Symmetric by construction.
create policy channel_membership_requests_decide on channel_membership_requests
  for update using (
    (direction = 'invite' and user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  )
  with check (
    (direction = 'invite' and user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  );
-- The side that *sent* a still-pending invite/request can withdraw it
-- themselves (mirrors a "cancel friend request" action) -- distinct from
-- deciding, which is always the *other* side's call.
create policy channel_membership_requests_originator_delete on channel_membership_requests
  for delete using (
    status = 'pending'
    and (
      (direction = 'invite' and is_home_space_owner(channel_id))
      or (direction = 'request' and user_id = auth.uid())
    )
  );

alter table channel_share_requests enable row level security;

create policy channel_share_requests_select on channel_share_requests
  for select using (target_user_id = auth.uid() or is_home_space_owner(channel_id) or is_staff());
create policy channel_share_requests_insert on channel_share_requests
  for insert with check (
    (direction = 'invite' and is_home_space_owner(channel_id))
    or (direction = 'request' and target_user_id = auth.uid() and is_space_owner(space_id))
  );
-- Deciding a share *invite* also supplies space_id (the accepting person's
-- own chosen Space) in the same update -- the WITH CHECK's
-- is_space_owner(space_id) makes sure they can only ever pick a Space
-- they themselves own.
create policy channel_share_requests_decide on channel_share_requests
  for update using (
    (direction = 'invite' and target_user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  )
  with check (
    (direction = 'invite' and target_user_id = auth.uid() and (space_id is null or is_space_owner(space_id)))
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  );
create policy channel_share_requests_originator_delete on channel_share_requests
  for delete using (
    status = 'pending'
    and (
      (direction = 'invite' and is_home_space_owner(channel_id))
      or (direction = 'request' and target_user_id = auth.uid())
    )
  );

alter table frames enable row level security;

create policy frames_select on frames
  for select using (is_space_owner(space_id) or is_staff());
create policy frames_owner_insert on frames
  for insert with check (is_space_owner(space_id));
create policy frames_owner_update on frames
  for update using (is_space_owner(space_id) or is_staff())
  with check (is_space_owner(space_id) or is_staff());
create policy frames_owner_delete on frames
  for delete using (is_space_owner(space_id) or is_staff());

-- Never exposed to any client role -- only service-role Edge Functions.
alter table frame_credentials enable row level security;

create policy frame_credentials_staff_select on frame_credentials
  for select using (is_staff());

alter table frame_channels enable row level security;

create policy frame_channels_select on frame_channels
  for select using (
    exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
    or is_staff()
  );
create policy frame_channels_owner_write on frame_channels
  for all using (
    exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
    and can_view_channel(channel_id)
  )
  with check (
    exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
    and can_view_channel(channel_id)
  );

alter table media_items enable row level security;

create policy media_items_select on media_items
  for select using (can_view_channel(channel_id));
create policy media_items_insert on media_items
  for insert with check (sender_id = auth.uid() and is_channel_member(channel_id));
create policy media_items_delete on media_items
  for delete using (sender_id = auth.uid() or is_home_space_owner(channel_id) or is_staff());

alter table media_item_hides enable row level security;

create policy media_item_hides_select on media_item_hides
  for select using (user_id = auth.uid());

alter table media_recipients enable row level security;

create policy media_recipients_select on media_recipients
  for select using (can_view_channel(channel_id) or is_staff());

alter table profiles enable row level security;

create policy profiles_self_select on profiles
  for select using (user_id = auth.uid() or is_staff());
create policy profiles_self_insert on profiles
  for insert with check (user_id = auth.uid());
create policy profiles_self_update on profiles
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table user_push_tokens enable row level security;

create policy user_push_tokens_self_all on user_push_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter table app_releases enable row level security;

create policy app_releases_select on app_releases
  for select using (auth.role() = 'authenticated' or is_staff());
create policy app_releases_staff_write on app_releases
  for all using (is_staff()) with check (is_staff());

-- =========================================================================
-- 10. Realtime -- live feed/membership updates for the Smile app
-- =========================================================================

alter publication supabase_realtime add table
  channels, channel_members, channel_shares, media_items, media_recipients, frames;
