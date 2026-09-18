// Fans a newly-ready media_item out to media_recipients -- one row per
// Frame assigned to the item's channel (frame_channels, see
// migrations/0031_architecture_reset.sql). This has to run somewhere after
// processing_status flips to 'ready' (get-media-batch only ever returns
// ready items), and both completion paths -- the synchronous passthrough
// fallback in complete-upload and the async media-processing-service
// callback -- need it, so it lives here once rather than duplicated in
// both. Also pushes each Frame a "sync now" so the new photo shows up
// immediately instead of waiting for the next periodic poll, and
// (separately) notifies the channel's human members.
import { pushSyncNowToFrames } from "./push-frames.ts";
import { pushNotificationToUsers } from "./push-users.ts";

// deno-lint-ignore no-explicit-any
export async function fanOutToFrames(supabaseAdmin: any, mediaItemId: string, channelId: string): Promise<void> {
  const { data: mediaItem } = await supabaseAdmin
    .from("media_items")
    .select("created_at, sender_id")
    .eq("id", mediaItemId)
    .maybeSingle();
  const sortOrder = mediaItem ? new Date(mediaItem.created_at).getTime() : Date.now();

  const { data: frameLinks } = await supabaseAdmin
    .from("frame_channels")
    .select("frame_id")
    .eq("channel_id", channelId);

  const frameIds = (frameLinks ?? []).map((l: { frame_id: string }) => l.frame_id);

  if (frameIds.length > 0) {
    await supabaseAdmin.from("media_recipients").upsert(
      frameIds.map((frameId: string) => ({
        media_item_id: mediaItemId,
        frame_id: frameId,
        channel_id: channelId,
        sort_order: sortOrder,
      })),
      { onConflict: "media_item_id,frame_id", ignoreDuplicates: true },
    );

    await pushSyncNowToFrames(supabaseAdmin, frameIds);
  }

  await notifyChannelMembersOfNewPhoto(supabaseAdmin, channelId, mediaItem?.sender_id ?? null);
}

/** Best-effort human-facing push for every other member of the channel -- the sender already knows they just posted. */
// deno-lint-ignore no-explicit-any
async function notifyChannelMembersOfNewPhoto(supabaseAdmin: any, channelId: string, senderId: string | null): Promise<void> {
  const [{ data: members }, { data: channel }] = await Promise.all([
    supabaseAdmin.from("channel_members").select("user_id").eq("channel_id", channelId),
    supabaseAdmin.from("channels").select("name").eq("id", channelId).maybeSingle(),
  ]);
  const recipientIds = (members ?? [])
    .map((m: { user_id: string }) => m.user_id)
    .filter((id: string) => id !== senderId);
  if (recipientIds.length === 0) return;

  await pushNotificationToUsers(
    supabaseAdmin,
    recipientIds,
    { title: channel?.name ?? "Neues Foto", body: "Ein neues Foto wurde geteilt." },
    { type: "new_photo", channel_id: channelId, channel_name: channel?.name ?? "" },
  );
}
