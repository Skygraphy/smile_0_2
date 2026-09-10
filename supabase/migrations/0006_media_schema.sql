-- Media is channel-scoped (not space-wide): a photo belongs to exactly one
-- Channel. Which devices show it is a separate curation step
-- (media_recipients), requiring the device to actually be assigned to that
-- channel (channel_memberships role='device') -- this fully replaces the
-- smile_0_1 prototype's tenant-wide "device_senders" pairing table.
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
  processing_status text not null default 'uploaded'
    check (processing_status in ('uploaded', 'processing', 'ready', 'failed')),
  caption text,
  created_at timestamptz not null default now()
);

create index idx_media_items_channel on media_items(channel_id);
create index idx_media_items_sender on media_items(sender_id);

create table media_recipients (
  id uuid primary key default gen_random_uuid(),
  media_item_id uuid not null references media_items(id) on delete cascade,
  device_id uuid not null references devices(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  delivered_at timestamptz,
  viewed_at timestamptz,
  sort_order bigint not null default (extract(epoch from now()) * 1000)::bigint,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  unique (media_item_id, device_id)
);

create index idx_media_recipients_device_sort
  on media_recipients(device_id, sort_order) where hidden_at is null;
