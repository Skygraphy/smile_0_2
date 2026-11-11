-- Who may run the voucher administration (2026-11-11). Not staff_members:
-- is_staff() opens every Space to reading (RLS), which an everyday Smile
-- account (Ernst's own) must never get. This grants only voucher-admin.
create table voucher_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table voucher_admins enable row level security;
-- No policies: only the voucher-admin Edge Function (service role) reads it.
