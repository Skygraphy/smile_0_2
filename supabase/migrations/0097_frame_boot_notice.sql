-- "Frame läuft wieder" (2026-11-05): when a Frame's tablet has just been
-- switched on again (power cut, restart), its managers hear so -- with the
-- hint to pin it again. At most every 30 minutes per Frame.
alter table frames add column if not exists boot_notice_at timestamptz;
