// Fans a newly-ready media_item out to media_recipients -- one row per
// device assigned to the item's channel (channel_memberships role='device'),
// per the curation model in migrations/0006_media_schema.sql. This has to
// run somewhere after processing_status flips to 'ready' (get-media-batch
// only ever returns ready items), and both completion paths -- the
// synchronous passthrough fallback in complete-upload and the async
// media-processing-service callback -- need it, so it lives here once
// rather than duplicated in both. Also pushes each device a "sync now" so
// the new photo shows up immediately instead of waiting for the next
// periodic poll, and (separately) notifies the channel's human members.
import { pushSyncNowToDevices } from "./push-devices.ts";
import { pushNotificationToUsers } from "./push-users.ts";

// deno-lint-ignore no-explicit-any
export async function fanOutToDevices(supabaseAdmin: any, mediaItemId: string, channelId: string): Promise<void> {
  const { data: mediaItem } = await supabaseAdmin
    .from("media_items")
    .select("created_at, sender_id")
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

  if (deviceIds.length > 0) {
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

  await notifyChannelMembersOfNewPhoto(supabaseAdmin, channelId, mediaItem?.sender_id ?? null);
}

/** Best-effort human-facing push for every other member of the channel -- the sender already knows they just posted. */
// deno-lint-ignore no-explicit-any
async function notifyChannelMembersOfNewPhoto(supabaseAdmin: any, channelId: string, senderId: string | null): Promise<void> {
  const [{ data: memberships }, { data: channel }] = await Promise.all([
    supabaseAdmin
      .from("channel_memberships")
      .select("user_id")
      .eq("channel_id", channelId)
      .not("user_id", "is", null),
    supabaseAdmin.from("channels").select("name").eq("id", channelId).maybeSingle(),
  ]);
  const recipientIds = (memberships ?? [])
    .map((m: { user_id: string | null }) => m.user_id)
    .filter((id: string | null): id is string => Boolean(id) && id !== senderId);
  if (recipientIds.length === 0) return;

  await pushNotificationToUsers(
    supabaseAdmin,
    recipientIds,
    { title: channel?.name ?? "Neues Foto", body: "Ein neues Foto wurde geteilt." },
    { type: "new_photo", channel_id: channelId, channel_name: channel?.name ?? "" },
  );
}
