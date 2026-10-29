-- Whether a stopped photo keeps its slow zoom (Ernst 2026-10-30): on, it
-- carries on at the same speed; off, it holds its size and goes on from
-- there when the Frame runs again.
alter table frames add column if not exists pause_zoom boolean not null default true;
