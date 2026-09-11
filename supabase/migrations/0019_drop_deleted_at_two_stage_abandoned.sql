-- Two-stage soft-delete (0018_media_delete.sql's deleted_at column) was
-- built, shipped, and then explicitly abandoned in the same session: the
-- product decision landed on a single confirmed "for everyone" action being
-- an immediate, real delete (row + storage objects) everywhere -- every
-- Smile-App client, every Smile-Frame, the DB, and every cache -- rather
-- than leaving a persistent placeholder that needs a second confirm to
-- actually go away. media_item_hides ("for me" personal hide) is unaffected
-- and stays exactly as it was.
alter table media_items drop column deleted_at;
