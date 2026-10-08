// Runs once a media_item turns 'ready' -- from both completion paths (the
// synchronous passthrough fallback in complete-upload and the async
// media-processing-service callback). Frames need nothing from here any
// more: they compute their content live (migrations/0049) and the
// media_items update itself wakes them (sync_notify). What remains is the
// visible "new photo" notification for the channel's human members.
import { pushNotificationToUsers } from "./push-users.ts";
import { fetchProfilesByUserId } from "./profiles.ts";

/** Photos a sender posts within this many minutes count as one batch. */
const BATCH_MINUTES = 10;

// deno-lint-ignore no-explicit-any
export async function announceReadyPhoto(supabaseAdmin: any, mediaItemId: string, channelId: string): Promise<void> {
  const { data: mediaItem } = await supabaseAdmin
    .from("media_items")
    .select("sender_id")
    .eq("id", mediaItemId)
    .maybeSingle();
  await notifyChannelMembersOfNewPhoto(supabaseAdmin, channelId, mediaItem?.sender_id ?? null);
}

/** "5 neue Fotos" instead of "Foto" -- only the media types actually in the batch. */
export function batchBody(senderName: string, photos: number, videos: number): string {
  const total = photos + videos;
  if (total <= 1) return `${senderName} hat ${videos === 1 ? "ein Video" : "ein Foto"} geteilt.`;
  const kind = videos === 0 ? "Fotos" : photos === 0 ? "Videos" : "Fotos und Videos";
  return `${senderName} hat ${total} neue ${kind} geteilt.`;
}

/**
 * Best-effort human-facing push for every other member of the channel -- the
 * sender already knows they just posted. Several photos in one go (decided
 * 2026-10-08) end up as ONE notification per album and sender that keeps
 * counting up ("Ernst hat 5 neue Fotos geteilt."), not one per photo.
 */
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

  let photos = 1;
  let videos = 0;
  let senderName = "Jemand";
  if (senderId) {
    const since = new Date(Date.now() - BATCH_MINUTES * 60_000).toISOString();
    const [{ data: batch }, profiles] = await Promise.all([
      supabaseAdmin
        .from("media_items")
        .select("media_type")
        .eq("channel_id", channelId)
        .eq("sender_id", senderId)
        .eq("processing_status", "ready")
        .gte("created_at", since),
      fetchProfilesByUserId(supabaseAdmin, [senderId]),
    ]);
    const types = (batch ?? []).map((m: { media_type: string }) => m.media_type);
    if (types.length > 0) {
      videos = types.filter((t: string) => t === "video").length;
      photos = types.length - videos;
    }
    senderName = profiles.get(senderId)?.display_name ?? senderName;
  }

  await pushNotificationToUsers(
    supabaseAdmin,
    recipientIds,
    { title: channel?.name ?? "Neues Foto", body: batchBody(senderName, photos, videos) },
    { type: "new_photo", channel_id: channelId, channel_name: channel?.name ?? "" },
    senderId ? { collapseKey: `photos_${channelId}_${senderId}`, collapseWindowMinutes: BATCH_MINUTES } : undefined,
  );
}
