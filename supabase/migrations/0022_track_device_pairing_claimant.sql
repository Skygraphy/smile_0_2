-- Tracks which user paired a Frame to a Space (concept doc sect. 14-16
-- device provisioning flow). Previously only devices.space_id survived the
-- claim -- there was no record of who performed it.
--
-- The claim (claim-device-pairing) and the actual activation
-- (poll-device-pairing, run by the device itself once it observes the
-- claim) are two different requests, so the claiming user id has to be
-- staged on pairing_codes first and copied onto devices at activation time,
-- mirroring how space_id already flows through this same handoff.

alter table pairing_codes add column claimed_by_user_id uuid references auth.users(id);
alter table devices add column paired_by_user_id uuid references auth.users(id);
