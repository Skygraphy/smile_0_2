// Fans a newly-ready media_item out to media_recipients -- one row per
// device assigned to the item's channel (channel_memberships role='device'),
// per the curation model in migrations/0006_media_schema.sql. This has to
// run somewhere after processing_status flips to 'ready' (get-media-batch
// only ever returns ready items), and both completion paths -- the
// synchronous passthrough fallback in complete-upload and the async
// media-processing-service callback -- need it, so it lives here once
// rather than duplicated in both. Also pushes each device a "sync now" so
// the new photo shows up immediately instead of waiting for the next
// periodic poll.
import { pushSyncNowToDevices } from "./push-devices.ts";

// deno-lint-ignore no-explicit-any
export async function fanOutToDevices(supabaseAdmin: any, mediaItemId: string, channelId: string): Promise<void> {
  const { data: mediaItem } = await supabaseAdmin
    .from("media_items")
    .select("created_at")
    .eq("id", mediaItemId)
    .maybeSingle();
  const sortOrder = mediaItem ? new Date(mediaItem.created_at).getTime() : Date.now();

  const { data: deviceMemberships } = await supabaseAdmin
    .from("channel_memberships")
    .select("device_id")
    .eq("channel_id", channelId)
    .eq("role", "device");

  const deviceIds = (deviceMemberships ?? [])
    .map((m: { device_id: string | null }) => m.device_id)
    .filter((id: string | null): id is string => Boolean(id));
  if (deviceIds.length === 0) return;

  await supabaseAdmin.from("media_recipients").upsert(
    deviceIds.map((deviceId: string) => ({
      media_item_id: mediaItemId,
      device_id: deviceId,
      channel_id: channelId,
      sort_order: sortOrder,
    })),
    { onConflict: "media_item_id,device_id", ignoreDuplicates: true },
  );

  await pushSyncNowToDevices(supabaseAdmin, deviceIds);
}
