-- WhatsApp-style instant preview: a tiny (client-generated, low-quality)
-- data-URI thumbnail stored inline on the row itself, so other channel
-- members' feeds can render *something* the moment the row is created
-- (media_items_select already lets any channel member read any row in
-- their channel regardless of processing_status) instead of waiting for
-- the full upload + server-side resize/thumbnail pipeline to finish.
-- Capped well under Postgres's TOAST-inline threshold -- this is meant to
-- be a ~1-3KB blurry placeholder, not a real thumbnail.
alter table media_items add column preview_data_url text
  check (preview_data_url is null or length(preview_data_url) <= 20000);
