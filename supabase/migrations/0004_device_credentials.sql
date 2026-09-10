-- Device refresh-credential store, fixing a known smile_0_1 gap: the
-- prototype's device JWT had no rotation mechanism at all (5-year TTL
-- worked around a short-TTL-with-no-refresh bug instead of fixing it, and
-- revocation was all-or-nothing via the shared signing secret). Here, each
-- device gets its own rotating refresh secret; only its hash is stored.
-- Never exposed to any client role directly (see 0009) -- only Edge
-- Functions using the service-role key read/write this table.
create table device_credentials (
  device_id uuid primary key references devices(id) on delete cascade,
  refresh_secret_hash text not null,
  refresh_secret_version int not null default 1,
  access_token_ttl_seconds int not null default 3600,
  created_at timestamptz not null default now(),
  rotated_at timestamptz,
  revoked_at timestamptz
);
