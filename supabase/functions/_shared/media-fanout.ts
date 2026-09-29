// Runs once a media_item turns 'ready' -- from both completion paths (the
// synchronous passthrough fallback in complete-upload and the async
// media-processing-service callback). Frames need nothing from here any
// more: they compute their content live (migrations/0049) and the
// media_items update itself wakes them (sync_notify). What remains is the
// visible "new photo" notification for the channel's human members.
import { pushNotificationToUsers } from "./push-users.ts";

// deno-lint-ignore no-explicit-any
export async function announceReadyPhoto(supabaseAdmin: any, mediaItemId: string, channelId: string): Promise<void> {
  const { data: mediaItem } = await supabaseAdmin
    .from("media_items")
    .select("sender_id")
    .eq("id", mediaItemId)
    .maybeSingle();
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
