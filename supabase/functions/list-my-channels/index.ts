// Powers the channel-first home screen (channels_home_screen.dart):
// WhatsApp's own chat list shows conversations sorted by recency, not a
// Space/Frame hierarchy first. Every channel the caller can view: a direct
// channel_members row (this always includes the SCO too, auto-joined by
// the on_channel_created trigger -- migrations/0031_architecture_reset.sql),
// or a channel shared (channel_shares, view-only) into a Space they own.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { visibleChannelIds } from "../_shared/channel-access.ts";

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

  // Everything this person can see -- own/co-owned Spaces' channels,
  // channels they post in, channels shared into a Space they manage. The
  // single source (migrations/0047); before, this list forgot co-owners.
  const channelIds = await visibleChannelIds(supabaseAdmin, userId);
  if (channelIds.length === 0) return jsonResponse({ channels: [] });

  // Only for the "nur ansehen" label -- posting rights are membership.
  const { data: memberships } = await supabaseAdmin.from("channel_members").select("channel_id").eq("user_id", userId);
  const memberChannelIds = (memberships ?? []).map((m) => m.channel_id as string);

  const [{ data: channels, error: channelsError }, { data: shareRows }] = await Promise.all([
    // The explicit `!channels_space_id_fkey` hint is required: PostgREST
    // can also reach `spaces` from `channels` indirectly through
    // `channel_shares` (which has FKs to both), so a bare `spaces(...)`
    // embed is ambiguous (PGRST201: "more than one relationship was
    // found") the moment PostgREST's schema cache has picked up
    // channel_shares' FKs -- independent of whether any row actually
    // exists in it. This is why it wasn't caught during Phase 1-3
    // testing (done shortly after the schema reset, likely before
    // PostgREST's cache had settled) but broke on the very first real
    // walkthrough afterward.
    supabaseAdmin.from("channels").select("id, name, space_id, spaces!channels_space_id_fkey(id, name), created_at").in("id", channelIds),
    // Every Space this channel is shared into (not just the caller's own)
    // -- a shared channel shows both households' Space names, the same
    // reason WhatsApp shows every member of a group, not just the ones
    // you personally know.
    supabaseAdmin.from("channel_shares").select("channel_id, spaces(id, name, deleted_at)").in("channel_id", channelIds),
  ]);
  if (channelsError) return jsonResponse({ error: "fetch_failed" }, 500);

  const sharedSpacesByChannel = new Map<string, { id: string; name: string }[]>();
  for (const row of shareRows ?? []) {
    // deno-lint-ignore no-explicit-any
    const space = row.spaces as any;
    if (!space || space.deleted_at) continue;
    const channelId = row.channel_id as string;
    const list = sharedSpacesByChannel.get(channelId) ?? [];
    list.push({ id: space.id, name: space.name });
    sharedSpacesByChannel.set(channelId, list);
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
    // deno-lint-ignore no-explicit-any
    const homeSpace = c.spaces as any;
    const spaces = [
      ...(homeSpace ? [{ id: homeSpace.id as string, name: homeSpace.name as string }] : []),
      ...(sharedSpacesByChannel.get(c.id as string) ?? []),
    ];
    return {
      channel_id: c.id,
      channel_name: c.name,
      spaces,
      is_member: memberChannelIds.includes(c.id as string),
      // No photo yet -> sort by the channel's own creation time, so a
      // brand-new empty channel still shows up in a sensible spot instead
      // of falling to the very bottom indefinitely.
      last_activity_at: lastActivityByChannel.get(c.id as string) ?? c.created_at,
    };
  });

  resolved.sort((a, b) => (a.last_activity_at < b.last_activity_at ? 1 : a.last_activity_at > b.last_activity_at ? -1 : 0));

  return jsonResponse({ channels: resolved });
});
