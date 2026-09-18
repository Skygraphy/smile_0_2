-- Phase 2 (Edge Functions) gap found while porting the push-notification
-- fan-out: 0031_architecture_reset.sql moved every device-facing column
-- onto `frames` except fcm_token, which the old `devices` table had for
-- exactly this purpose (best-effort "sync now" push, see
-- _shared/push-frames.ts). Never exposed to any client role -- only
-- service-role Edge Functions ever read/write it (submit-heartbeat writes
-- it, get-media-batch writes it, push-frames.ts reads it), same as before.

alter table frames add column fcm_token text;
