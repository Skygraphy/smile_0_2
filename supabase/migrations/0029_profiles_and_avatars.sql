-- "Jeder User und jede Gruppe benötigt zumindest einen Namen und ein
-- Profilbild." Resolved (user confirmed via AskUserQuestion) as: a
-- display name is required, a real uploaded photo is optional -- when
-- absent, the client always renders a generated initials avatar
-- (SmileAvatar) instead of a blank/anonymous placeholder, so "at least a
-- profile picture" is satisfied without forcing an upload step.

create table profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_path text,
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- Self-managed only, mirroring user_push_tokens (migrations/0028): every
-- roster/member-list edge function that needs to show someone else's
-- name/avatar resolves it with the service-role key, the same way those
-- functions already resolve auth.users.email -- never a broad client-side
-- select policy exposing every user's profile to every other user.
create policy profiles_self_select on profiles
  for select using (user_id = auth.uid() or is_staff());

create policy profiles_self_insert on profiles
  for insert with check (user_id = auth.uid());

create policy profiles_self_update on profiles
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Groups (migrations/0020) already require a name at creation; this adds
-- the optional-avatar half of the same requirement. No new RLS needed --
-- groups_owner_all already covers update of this column for the owner.
alter table groups add column avatar_path text;

-- One shared bucket for both user and group avatars, path-namespaced
-- (`users/<user_id>`, `groups/<group_id>`, no file extension -- content
-- type is stored as upload metadata, not inferred from the path). Public
-- read: avatars are low-sensitivity, cacheable images, unlike the
-- channel-isolated family photos in the media pipeline, so a public URL
-- (no signed-URL refresh machinery) is the right tradeoff here.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy avatars_public_read on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_user_write on storage.objects
  for all using (bucket_id = 'avatars' and name = 'users/' || auth.uid()::text)
  with check (bucket_id = 'avatars' and name = 'users/' || auth.uid()::text);

-- Only the group's owner (or staff) may set its avatar -- mirrors
-- groups_owner_all's own authorization, not a new capability.
create policy avatars_group_owner_write on storage.objects
  for all using (
    bucket_id = 'avatars'
    and name like 'groups/%'
    and exists (
      select 1 from groups g
      where g.id::text = split_part(name, '/', 2) and (g.owner_id = auth.uid() or is_staff())
    )
  )
  with check (
    bucket_id = 'avatars'
    and name like 'groups/%'
    and exists (
      select 1 from groups g
      where g.id::text = split_part(name, '/', 2) and (g.owner_id = auth.uid() or is_staff())
    )
  );
