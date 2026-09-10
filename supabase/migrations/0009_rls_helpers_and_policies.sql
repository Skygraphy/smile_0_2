-- RLS helper functions + policies for every table. Generalizes the
-- smile_0_1 prototype's is_tenant_member/is_tenant_admin/is_own_device/
-- is_staff pattern from flat-tenant scope to Space/Channel scope.
--
-- Resource-isolation guarantee (concept doc sect. 7-9): every content-
-- bearing table carries channel_id, and every SELECT policy on it goes
-- through is_channel_member/is_channel_device/is_channel_admin -- never a
-- space-wide predicate. A channel member can never see who belongs to, or
-- what is posted in, another channel of the same space.

-- =========================================================================
-- Helper functions
-- =========================================================================

create or replace function is_space_owner(check_space_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from space_owners
    where space_id = check_space_id and user_id = auth.uid()
  );
$$;

create or replace function is_channel_member(check_channel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from channel_memberships
    where channel_id = check_channel_id and user_id = auth.uid()
  );
$$;

create or replace function is_channel_admin(check_channel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from channel_memberships
    where channel_id = check_channel_id and user_id = auth.uid() and role = 'channel_admin'
  );
$$;

create or replace function is_channel_contributor_or_above(check_channel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from channel_memberships
    where channel_id = check_channel_id
      and user_id = auth.uid()
      and role in ('channel_admin', 'contributor')
  );
$$;

-- Does the current device JWT (device_id claim) match, and is the device
-- still allowed to act (not revoked/retired/unpaired)? This is the actual
-- per-device revocation mechanism: flipping lifecycle_state to 'revoked'
-- immediately rejects even a still-unexpired access token.
create or replace function is_own_device(check_device_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select coalesce((auth.jwt() ->> 'device_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid) = check_device_id
    and exists (
      select 1 from devices
      where id = check_device_id and lifecycle_state in ('active', 'offline')
    );
$$;

create or replace function is_channel_device(check_channel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from channel_memberships cm
    where cm.channel_id = check_channel_id
      and cm.role = 'device'
      and is_own_device(cm.device_id)
  );
$$;

create or replace function is_staff()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from staff_members where user_id = auth.uid());
$$;

-- =========================================================================
-- spaces
-- =========================================================================

alter table spaces enable row level security;

create policy spaces_select on spaces
  for select using (
    is_space_owner(id)
    or is_staff()
    or exists (
      select 1 from channels c
      join channel_memberships cm on cm.channel_id = c.id
      where c.space_id = spaces.id and cm.user_id = auth.uid()
    )
  );

-- Self-serve creation: any authenticated user may create a Space (concept
-- doc sect. 35). The on_space_created trigger (0003) then makes them its
-- first owner in the same transaction.
create policy spaces_insert_authenticated on spaces
  for insert with check (auth.role() = 'authenticated');

create policy spaces_owner_update on spaces
  for update using (is_space_owner(id) or is_staff())
  with check (is_space_owner(id) or is_staff());

create policy spaces_staff_delete on spaces
  for delete using (is_staff());

-- =========================================================================
-- staff_members
-- =========================================================================

alter table staff_members enable row level security;

create policy staff_members_staff_only on staff_members
  for all using (is_staff()) with check (is_staff());

-- =========================================================================
-- channels
-- =========================================================================

alter table channels enable row level security;

create policy channels_select on channels
  for select using (
    is_space_owner(space_id) or is_channel_member(id) or is_channel_admin(id) or is_staff()
  );
create policy channels_owner_insert on channels
  for insert with check (is_space_owner(space_id) or is_staff());
create policy channels_admin_update on channels
  for update using (is_space_owner(space_id) or is_channel_admin(id) or is_staff())
  with check (is_space_owner(space_id) or is_channel_admin(id) or is_staff());
create policy channels_owner_delete on channels
  for delete using (is_space_owner(space_id) or is_staff());

-- =========================================================================
-- space_owners
-- =========================================================================

alter table space_owners enable row level security;

create policy space_owners_select on space_owners
  for select using (is_space_owner(space_id) or is_staff());
create policy space_owners_write on space_owners
  for all using (is_space_owner(space_id) or is_staff())
  with check (is_space_owner(space_id) or is_staff());

-- =========================================================================
-- channel_memberships
-- =========================================================================

alter table channel_memberships enable row level security;

create policy channel_memberships_select on channel_memberships
  for select using (
    is_channel_member(channel_id)
    or is_channel_admin(channel_id)
    or is_own_device(device_id)
    or is_staff()
    or exists (select 1 from channels c where c.id = channel_memberships.channel_id and is_space_owner(c.space_id))
  );
create policy channel_memberships_admin_write on channel_memberships
  for all using (
    is_channel_admin(channel_id)
    or is_staff()
    or exists (select 1 from channels c where c.id = channel_memberships.channel_id and is_space_owner(c.space_id))
  )
  with check (
    is_channel_admin(channel_id)
    or is_staff()
    or exists (select 1 from channels c where c.id = channel_memberships.channel_id and is_space_owner(c.space_id))
  );

-- =========================================================================
-- devices
-- =========================================================================

alter table devices enable row level security;

create policy devices_select on devices
  for select using (is_space_owner(space_id) or is_own_device(id) or is_staff());
create policy devices_owner_insert on devices
  for insert with check (is_space_owner(space_id) or is_staff());
create policy devices_update on devices
  for update using (is_space_owner(space_id) or is_own_device(id) or is_staff())
  with check (is_space_owner(space_id) or is_own_device(id) or is_staff());

-- =========================================================================
-- device_policies
-- =========================================================================

alter table device_policies enable row level security;

create policy device_policies_select on device_policies
  for select using (
    is_own_device(device_id)
    or is_staff()
    or exists (select 1 from devices d where d.id = device_policies.device_id and is_space_owner(d.space_id))
  );
create policy device_policies_owner_write on device_policies
  for all using (
    is_staff()
    or exists (select 1 from devices d where d.id = device_policies.device_id and is_space_owner(d.space_id))
  )
  with check (
    is_staff()
    or exists (select 1 from devices d where d.id = device_policies.device_id and is_space_owner(d.space_id))
  );

-- =========================================================================
-- device_heartbeats
-- =========================================================================

alter table device_heartbeats enable row level security;

create policy device_heartbeats_select on device_heartbeats
  for select using (is_space_owner(space_id) or is_staff());
create policy device_heartbeats_device_insert on device_heartbeats
  for insert with check (is_own_device(device_id) or is_staff());

-- =========================================================================
-- device_credentials -- never touched by client roles, only Edge Functions
-- (service role, which bypasses RLS). Staff get read-only visibility for
-- support/debugging; nobody gets insert/update/delete via the API.
-- =========================================================================

alter table device_credentials enable row level security;

create policy device_credentials_staff_select on device_credentials
  for select using (is_staff());

-- =========================================================================
-- pairing_codes
-- =========================================================================

alter table pairing_codes enable row level security;

-- device_provisioning codes: Space Owner (or staff) only.
-- channel_invite codes: any channel member may create/see them; only a
-- Channel Admin (or staff) may revoke (delete) or otherwise write them --
-- matches the concept doc's member-initiated invite flow while keeping
-- revocation admin-only.
create policy pairing_codes_admin_all on pairing_codes
  for all using (
    (code_type = 'device_provisioning' and (is_space_owner(space_id) or is_staff()))
    or (code_type = 'channel_invite' and (is_channel_admin(channel_id) or is_staff()))
  )
  with check (
    (code_type = 'device_provisioning' and (is_space_owner(space_id) or is_staff()))
    or (code_type = 'channel_invite' and (is_channel_admin(channel_id) or is_staff()))
  );

create policy pairing_codes_channel_invite_member_insert on pairing_codes
  for insert with check (code_type = 'channel_invite' and is_channel_member(channel_id));

create policy pairing_codes_channel_invite_member_select on pairing_codes
  for select using (code_type = 'channel_invite' and is_channel_member(channel_id));

-- =========================================================================
-- media_items
-- =========================================================================

alter table media_items enable row level security;

create policy media_items_select on media_items
  for select using (is_channel_member(channel_id) or is_channel_admin(channel_id) or is_staff());
create policy media_items_insert on media_items
  for insert with check (sender_id = auth.uid() and is_channel_contributor_or_above(channel_id));
create policy media_items_delete on media_items
  for delete using (sender_id = auth.uid() or is_channel_admin(channel_id) or is_staff());

-- =========================================================================
-- media_recipients
-- =========================================================================

alter table media_recipients enable row level security;

create policy media_recipients_select on media_recipients
  for select using (is_channel_member(channel_id) or is_own_device(device_id) or is_staff());

-- Curation (assigning an uploaded photo to a device) requires the acting
-- user to be a member of the channel AND the target device to actually be
-- assigned to that channel (channel_memberships role='device') -- this
-- fully replaces the smile_0_1 prototype's tenant-wide "device_senders"
-- full-mesh pairing table.
create policy media_recipients_curate_insert on media_recipients
  for insert with check (
    is_channel_member(channel_id)
    and exists (
      select 1 from channel_memberships cm
      where cm.channel_id = media_recipients.channel_id
        and cm.device_id = media_recipients.device_id
        and cm.role = 'device'
    )
    and exists (
      select 1 from media_items mi
      where mi.id = media_recipients.media_item_id and mi.channel_id = media_recipients.channel_id
    )
  );

create policy media_recipients_device_update on media_recipients
  for update using (is_own_device(device_id) or is_channel_admin(channel_id) or is_staff())
  with check (is_own_device(device_id) or is_channel_admin(channel_id) or is_staff());

-- =========================================================================
-- remote_commands
-- =========================================================================

alter table remote_commands enable row level security;

create policy remote_commands_select on remote_commands
  for select using (is_space_owner(space_id) or is_own_device(device_id) or is_staff());
create policy remote_commands_insert on remote_commands
  for insert with check (is_space_owner(space_id) or is_staff());
create policy remote_commands_device_update on remote_commands
  for update using (is_own_device(device_id) or is_space_owner(space_id) or is_staff())
  with check (is_own_device(device_id) or is_space_owner(space_id) or is_staff());

-- =========================================================================
-- app_releases -- readable by any authenticated session (user OR device;
-- device JWTs also carry role=authenticated) so both apps can check the
-- current release; writable by staff only.
-- =========================================================================

alter table app_releases enable row level security;

create policy app_releases_select on app_releases
  for select using (auth.role() = 'authenticated' or is_staff());
create policy app_releases_staff_write on app_releases
  for all using (is_staff()) with check (is_staff());
