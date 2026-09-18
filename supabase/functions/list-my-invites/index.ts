// Resolves channel_membership_requests and channel_share_requests into a
// display-ready list. Needed as a service-role function for two reasons,
// not one:
//   1. profiles has no cross-user RLS (see _shared/profiles.ts) -- the
//      same reason every roster function already needs service role.
//   2. A pending invitee genuinely CANNOT see the channel's own name yet
//      via RLS (can_view_channel is false until they accept -- see
//      migrations/0031_architecture_reset.sql's header comment on why
//      that's deliberate: an invite must never leak the channel's photos
//      before someone has actually joined). Without this function an
//      invitee would have to accept blind.
//
// Two modes:
//   - `channel_id` given: the channel's SCO (or staff) reviewing every
//     pending request/invite for that one channel (the admin view).
//   - `channel_id` omitted: the caller's own personal inbox -- invites
//     addressed to them to decide, and the status of requests they made
//     themselves, across every channel.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id?: string;
}

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

  let body: RequestBody = {};
  try {
    body = (await req.json()) ?? {};
  } catch {
    // empty body is fine -- "my inbox" mode
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  let membershipQuery = supabaseAdmin
    .from("channel_membership_requests")
    .select("id, channel_id, user_id, direction, status, requested_at, decided_at")
    .order("requested_at", { ascending: false });
  let shareQuery = supabaseAdmin
    .from("channel_share_requests")
    .select("id, channel_id, target_user_id, space_id, direction, status, requested_at, decided_at")
    .order("requested_at", { ascending: false });

  if (body.channel_id) {
    const { data: channel } = await supabaseAdmin.from("channels").select("space_id").eq("id", body.channel_id).maybeSingle();
    if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);
    const { data: spaceRow } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle();
    if (!isStaff && spaceRow?.owner_id !== userId) return jsonResponse({ error: "not_channel_sco" }, 403);

    membershipQuery = membershipQuery.eq("channel_id", body.channel_id).eq("status", "pending");
    shareQuery = shareQuery.eq("channel_id", body.channel_id).eq("status", "pending");
  } else {
    membershipQuery = membershipQuery.eq("user_id", userId);
    shareQuery = shareQuery.eq("target_user_id", userId);
  }

  const [{ data: membershipRequests }, { data: shareRequests }] = await Promise.all([membershipQuery, shareQuery]);

  const channelIds = [
    ...new Set([...(membershipRequests ?? []).map((r) => r.channel_id), ...(shareRequests ?? []).map((r) => r.channel_id)]),
  ];
  const { data: channels } = channelIds.length > 0
    ? await supabaseAdmin.from("channels").select("id, name").in("id", channelIds)
    : { data: [] as { id: string; name: string }[] };
  const channelNameById = new Map((channels ?? []).map((c) => [c.id as string, c.name as string]));

  const counterpartIds = [
    ...new Set([...(membershipRequests ?? []).map((r) => r.user_id), ...(shareRequests ?? []).map((r) => r.target_user_id)]),
  ];
  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, counterpartIds);

  const membership = (membershipRequests ?? []).map((r) => {
    const profile = profilesByUserId.get(r.user_id as string);
    return {
      id: r.id,
      kind: "membership" as const,
      channel_id: r.channel_id,
      channel_name: channelNameById.get(r.channel_id as string) ?? null,
      counterpart_user_id: r.user_id,
      counterpart_display_name: profile?.display_name ?? null,
      counterpart_avatar_url: profile?.avatar_url ?? null,
      direction: r.direction,
      status: r.status,
      requested_at: r.requested_at,
      decided_at: r.decided_at,
    };
  });

  const shares = (shareRequests ?? []).map((r) => {
    const profile = profilesByUserId.get(r.target_user_id as string);
    return {
      id: r.id,
      kind: "share" as const,
      channel_id: r.channel_id,
      channel_name: channelNameById.get(r.channel_id as string) ?? null,
      counterpart_user_id: r.target_user_id,
      counterpart_display_name: profile?.display_name ?? null,
      counterpart_avatar_url: profile?.avatar_url ?? null,
      space_id: r.space_id,
      direction: r.direction,
      status: r.status,
      requested_at: r.requested_at,
      decided_at: r.decided_at,
    };
  });

  return jsonResponse({ membership_requests: membership, share_requests: shares });
});
