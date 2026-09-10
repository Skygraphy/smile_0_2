-- Core schema: Smile Space + Platform Administrator.
-- Every space-scoped table below carries space_id (directly, or via
-- channel_id/device_id) and is isolated via RLS (see 0009).

create extension if not exists "pgcrypto";

create table spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  plan text not null default 'family',
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now()
);

-- Platform Administrator: technical operator staff (system ops, device
-- management, support, abuse handling), deliberately not tied to any Space
-- (Separation of Duties between technical operation and content
-- administration -- concept doc sect. 10).
create table staff_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('support', 'ops_admin')),
  created_at timestamptz not null default now(),
  unique (user_id)
);
