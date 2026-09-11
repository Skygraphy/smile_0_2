-- Phase 6c: Channel-Beitrittsanfragen -- the self-service direction
-- invite codes (0009's pairing_codes_channel_invite_* policies) and
-- Groups (0020) both lack: "ich möchte selbst beitreten, ein Admin muss
-- zustimmen". Modeled as a second mode of the existing channel_invite
-- code rather than a new discovery mechanism, because channels_select RLS
-- never lets a non-member see a channel exists at all -- the invite code
-- is the only legitimate way a requester ever learns a channel_id to act
-- on. See claim-channel-invite/index.ts for the redemption-time branch.

alter table pairing_codes add column requires_approval boolean not null default false;

create table channel_join_requests (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  pairing_code_id uuid references pairing_codes(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id),
  unique (channel_id, user_id)
);

create index idx_channel_join_requests_channel on channel_join_requests(channel_id);

alter table channel_join_requests enable row level security;

-- Read-only from the client's perspective -- both the request-time upsert
-- (claim-channel-invite) and the decision (decide-channel-join-request)
-- go through service-role edge functions. This is defense-in-depth
-- visibility, matching every other table here: the requester can see
-- their own pending/decided status, and a channel admin/space owner/staff
-- can see requests for channels they administer.
create policy channel_join_requests_select on channel_join_requests
  for select using (
    user_id = auth.uid()
    or is_channel_admin(channel_id)
    or is_staff()
    or exists (select 1 from channels c where c.id = channel_join_requests.channel_id and is_space_owner(c.space_id))
  );
