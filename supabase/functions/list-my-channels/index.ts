// Powers the new channel-first home screen (channels_home_screen.dart):
// WhatsApp's own chat list shows conversations sorted by recency, not a
// device/contact hierarchy first -- the user's own framing was "Spaces/
// Channels/Frames are infrastructure behind the actual communication,
// which happens at the Channel level", so the home screen became a flat,
// recency-sorted Channel list instead of the old Space-first landing
// page. Every channel the caller can see (any direct membership role
// except 'device', or any channel in a Space they own outright -- same
// merge pattern as channel_picker_service.dart's listMyUploadableChannels,
// just viewer-inclusive since this is for *viewing*, not posting).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);

  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const [{ data: memberships }, { data: ownedSpaces }] = await Promise.all([
    supabaseAdmin.from("channel_memberships").select("channel_id").eq("user_id", userId).neq("role", "device"),
    supabaseAdmin.from("space_owners").select("space_id").eq("user_id", userId),
  ]);

  const memberChannelIds = (memberships ?? []).map((m) => m.channel_id as string);
  const ownedSpaceIds = (ownedSpaces ?? []).map((s) => s.space_id as string);

  // A channel can now be linked to more than one Space (space_channels) --
  // .in("space_id", ownedSpaceIds) can return the *same* channel_id twice
  // if the caller owns two Spaces both linked to it, so this de-dupes via
  // the Set below same as it already did for member vs. owned channels.
  const { data: ownedChannelLinks } =
    ownedSpaceIds.length > 0
      ? await supabaseAdmin.from("space_channels").select("channel_id").in("space_id", ownedSpaceIds)
      : { data: [] as { channel_id: string }[] };

  const channelIds = [
    ...new Set([...memberChannelIds, ...(ownedChannelLinks ?? []).map((c) => c.channel_id as string)]),
  ];
  if (channelIds.length === 0) return jsonResponse({ channels: [] });

  const [{ data: channels, error: channelsError }, { data: spaceLinks }] = await Promise.all([
    supabaseAdmin.from("channels").select("id, name, created_at").in("id", channelIds),
    // Every linked Space per channel (not just the caller's owned ones) --
    // a channel a Space Owner shares still shows the *other* household's
    // Space name too, for the same reason WhatsApp shows both members of
    // a group even ones you didn't personally add.
    supabaseAdmin.from("space_channels").select("channel_id, spaces(id, name)").in("channel_id", channelIds),
  ]);
  if (channelsError) return jsonResponse({ error: "fetch_failed" }, 500);

  const spacesByChannel = new Map<string, { id: string; name: string }[]>();
  for (const row of spaceLinks ?? []) {
    // deno-lint-ignore no-explicit-any
    const space = row.spaces as any;
    if (!space) continue;
    const channelId = row.channel_id as string;
    const list = spacesByChannel.get(channelId) ?? [];
    list.push({ id: space.id, name: space.name });
    spacesByChannel.set(channelId, list);
  }

  // Cheap two-column fetch across every candidate channel, not paged --
  // reducing to "latest per channel_id" client-side (below) is only
  // correct if this isn't silently truncated by a default row limit.
  const { data: mediaRows } = await supabaseAdmin
    .from("media_items")
    .select("channel_id, created_at")
    .in("channel_id", channelIds)
    .eq("processing_status", "ready")
    .order("created_at", { ascending: false })
    .limit(20000);

  const lastActivityByChannel = new Map<string, string>();
  for (const row of mediaRows ?? []) {
    const channelId = row.channel_id as string;
    if (!lastActivityByChannel.has(channelId)) {
      lastActivityByChannel.set(channelId, row.created_at as string);
    }
  }

  const resolved = (channels ?? []).map((c) => {
    return {
      channel_id: c.id,
      channel_name: c.name,
      spaces: spacesByChannel.get(c.id as string) ?? [],
      // No photo yet -> sort by the channel's own creation time, so a
      // brand-new empty channel still shows up in a sensible spot
      // instead of falling to the very bottom indefinitely.
      last_activity_at: lastActivityByChannel.get(c.id as string) ?? c.created_at,
    };
  });

  resolved.sort((a, b) => (a.last_activity_at < b.last_activity_at ? 1 : a.last_activity_at > b.last_activity_at ? -1 : 0));

  return jsonResponse({ channels: resolved });
});
