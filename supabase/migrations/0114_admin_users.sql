-- Verwaltung on smileapp.app (2026-11-21): who may work there and what.
--
-- One Super-Admin (Ernst, the developer), entered here directly -- never
-- through the website. The Super-Admin adds Admins on the website and ticks
-- what each may do: Meldungen (Hilfe & Feedback) and/or Gutscheine.
--
-- Not staff_members: is_staff() opens every Space to reading (RLS). This
-- table grants nothing inside the app -- only the Verwaltung functions
-- (feedback, voucher-admin, admin-users) read it, with the service role.
-- Replaces voucher_admins (0103).
create table admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin', 'admin')),
  -- What an Admin may do; the Super-Admin may always do everything.
  can_feedback boolean not null default false,
  can_vouchers boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
alter table admin_users enable row level security;
-- No policies: server-only.

-- Exactly one Super-Admin at most.
create unique index admin_users_one_super on admin_users ((true)) where role = 'super_admin';

-- Whoever ran the vouchers so far keeps doing so.
insert into admin_users (user_id, role, can_vouchers)
select user_id, 'admin', true from voucher_admins
on conflict (user_id) do nothing;
drop table voucher_admins;

-- Meldungen worked on the website: who took it, an internal note, who closed it.
alter table feedback_reports drop constraint feedback_reports_status_check;
alter table feedback_reports add constraint feedback_reports_status_check
  check (status in ('open', 'in_progress', 'done'));
alter table feedback_reports
  add column claimed_by uuid references auth.users(id) on delete set null,
  add column note text check (note is null or length(note) <= 5000),
  add column done_by uuid references auth.users(id) on delete set null;
