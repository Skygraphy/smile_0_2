-- "Was sieht Oma gerade?" (2026-11-18, Ernst): the Space's Admin or a
-- Co-Admin can look at a Frame's screen live -- for checking, not for
-- watching over anyone:
--   * only the Space's Admin and Co-Admins (not Frame-Admins, not staff);
--   * the Frame always shows "<Name> schaut mit" while it happens;
--   * no history: one picture per Frame, overwritten every few seconds,
--     deleted when looking ends;
--   * a look ends by itself after 5 minutes (start again to go on), and
--     within ~20 s once the app stops asking.
-- Only the Edge Function frame-live touches this.

create table frame_live (
  frame_id uuid primary key references frames(id) on delete cascade,
  watcher_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  -- The Frame keeps sending only while now() < until.
  until timestamptz not null,
  -- Last wake-up push to the Frame (re-sent when pictures stop coming).
  pushed_at timestamptz,
  -- The latest picture (storage frame-live/<frame_id>.png) and what the
  -- Frame said about itself: playing / paused / quiet / overview, album.
  captured_at timestamptz,
  state jsonb
);
alter table frame_live enable row level security;
-- No policies.

insert into storage.buckets (id, name, public)
values ('frame-live', 'frame-live', false)
on conflict (id) do nothing;
