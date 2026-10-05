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
import { isSpaceOwnerOrCoOwner, isStaff as checkStaff } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id?: string;
  /** Inbox mode only: also return pending *requests* (someone asking to
   * join, or to see an album with their Space) for every album in a
   * Space the caller manages -- the "Neuigkeiten" list (UI stage 6). */
  include_managed?: boolean;
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

  const isStaff = await checkStaff(supabaseAdmin, userId);

  // Both modes only ever want to-be-decided items -- the personal inbox
  // has no "history" view (my_invites_screen.dart shows nothing once a
  // request is decided), and the admin view is the SCO's action list, not
  // an audit log. Without this filter, an already-accepted/declined row
  // keeps matching `target_user_id = userId` / `user_id = userId` forever
  // and the personal inbox never lets go of it -- indistinguishable from a
  // fresh pending one, so accepting it again looks like tapping does
  // nothing (the trigger's `old.status = 'pending'` guard makes the second
  // decide a real no-op, but the row itself never left the list).
  let membershipQuery = supabaseAdmin
    .from("channel_membership_requests")
    .select("id, channel_id, user_id, direction, status, requested_at, decided_at")
    .eq("status", "pending")
    .order("requested_at", { ascending: false });
  let shareQuery = supabaseAdmin
    .from("channel_share_requests")
    .select("id, channel_id, target_user_id, space_id, direction, status, requested_at, decided_at")
    .eq("status", "pending")
    .order("requested_at", { ascending: false });

  if (body.channel_id) {
    const { data: channel } = await supabaseAdmin.from("channels").select("space_id").eq("id", body.channel_id).maybeSingle();
    if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);
    if (!isStaff && !(await isSpaceOwnerOrCoOwner(supabaseAdmin, channel.space_id, userId))) {
      return jsonResponse({ error: "not_channel_sco" }, 403);
    }

    membershipQuery = membershipQuery.eq("channel_id", body.channel_id);
    shareQuery = shareQuery.eq("channel_id", body.channel_id);
  } else {
    membershipQuery = membershipQuery.eq("user_id", userId);
    shareQuery = shareQuery.eq("target_user_id", userId);
  }

  const [{ data: membershipRequests }, { data: shareRequests }] = await Promise.all([membershipQuery, shareQuery]);

  const channelIds = [
    ...new Set([...(membershipRequests ?? []).map((r) => r.channel_id), ...(shareRequests ?? []).map((r) => r.channel_id)]),
  ];
  const { data: channels } = channelIds.length > 0
    ? await supabaseAdmin.from("channels").select("id, name, space_id").in("id", channelIds)
    : { data: [] as { id: string; name: string; space_id: string }[] };
  const channelNameById = new Map((channels ?? []).map((c) => [c.id as string, c.name as string]));

  // "my inbox" mode (no channel_id): every row's own `user_id`/
  // `target_user_id` is, by construction of the query filters above,
  // the CALLER's own id -- that column means "the non-SCO party" for
  // both directions, and here the caller themselves always *is* that
  // party (an invite addressed to them, or a request they made
  // themselves). So it can never be used as "the other party" in this
  // mode -- it would just echo the caller's own name back to them
  // (e.g. an invite from Ernst showing up on Roman's own inbox
  // labelled "Roman invites you..."). The actual other party here is
  // always the channel's SCO (the home Space's owner), resolved via
  // spaces.owner_id below.
  const isMyInboxMode = !body.channel_id;
  const scoByChannel = new Map<string, string>();
  if (isMyInboxMode && (channels ?? []).length > 0) {
    const spaceIds = [...new Set((channels ?? []).map((c) => c.space_id as string))];
    const { data: spaceRows } = await supabaseAdmin.from("spaces").select("id, owner_id").in("id", spaceIds);
    const ownerBySpace = new Map((spaceRows ?? []).map((s) => [s.id as string, s.owner_id as string]));
    for (const c of channels ?? []) {
      const ownerId = ownerBySpace.get(c.space_id as string);
      if (ownerId) scoByChannel.set(c.id as string, ownerId);
    }
  }
  const counterpartFor = (channelId: string, rowOtherPartyId: string): string =>
    isMyInboxMode ? scoByChannel.get(channelId) ?? rowOtherPartyId : rowOtherPartyId;

  const counterpartIds = [
    ...new Set([
      ...(membershipRequests ?? []).map((r) => counterpartFor(r.channel_id as string, r.user_id as string)),
      ...(shareRequests ?? []).map((r) => counterpartFor(r.channel_id as string, r.target_user_id as string)),
    ]),
  ];
  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, counterpartIds);

  const membership = (membershipRequests ?? []).map((r) => {
    const counterpartId = counterpartFor(r.channel_id as string, r.user_id as string);
    const profile = profilesByUserId.get(counterpartId);
    return {
      id: r.id,
      kind: "membership" as const,
      channel_id: r.channel_id,
      channel_name: channelNameById.get(r.channel_id as string) ?? null,
      counterpart_user_id: counterpartId,
      counterpart_display_name: profile?.display_name ?? null,
      counterpart_avatar_url: profile?.avatar_url ?? null,
      direction: r.direction,
      status: r.status,
      requested_at: r.requested_at,
      decided_at: r.decided_at,
    };
  });

  const shares = (shareRequests ?? []).map((r) => {
    const counterpartId = counterpartFor(r.channel_id as string, r.target_user_id as string);
    const profile = profilesByUserId.get(counterpartId);
    return {
      id: r.id,
      kind: "share" as const,
      channel_id: r.channel_id,
      channel_name: channelNameById.get(r.channel_id as string) ?? null,
      counterpart_user_id: counterpartId,
      counterpart_display_name: profile?.display_name ?? null,
      counterpart_avatar_url: profile?.avatar_url ?? null,
      space_id: r.space_id,
      direction: r.direction,
      status: r.status,
      requested_at: r.requested_at,
      decided_at: r.decided_at,
    };
  });

  if (!isMyInboxMode || !body.include_managed) {
    return jsonResponse({ membership_requests: membership, share_requests: shares });
  }

  // --- Requests waiting on the caller as a manager (Admin/Co-Admin) ----
  const [{ data: ownedSpaces }, { data: coOwnedSpaces }] = await Promise.all([
    supabaseAdmin.from("spaces").select("id").eq("owner_id", userId).is("deleted_at", null),
    supabaseAdmin.from("space_co_owners").select("space_id").eq("user_id", userId),
  ]);
  const managedSpaceIds = [
    ...new Set([...(ownedSpaces ?? []).map((s) => s.id as string), ...(coOwnedSpaces ?? []).map((s) => s.space_id as string)]),
  ];
  const { data: managedChannels } = managedSpaceIds.length > 0
    ? await supabaseAdmin.from("channels").select("id, name").in("space_id", managedSpaceIds).is("deleted_at", null)
    : { data: [] as { id: string; name: string }[] };
  const managedChannelName = new Map((managedChannels ?? []).map((c) => [c.id as string, c.name as string]));
  const managedIds = [...managedChannelName.keys()];

  const [{ data: managedMembership }, { data: managedShares }] = managedIds.length > 0
    ? await Promise.all([
      supabaseAdmin.from("channel_membership_requests")
        .select("id, channel_id, user_id, direction, status, requested_at, decided_at")
        .eq("status", "pending").eq("direction", "request").in("channel_id", managedIds)
        .order("requested_at", { ascending: false }),
      supabaseAdmin.from("channel_share_requests")
        .select("id, channel_id, target_user_id, space_id, direction, status, requested_at, decided_at")
        .eq("status", "pending").eq("direction", "request").in("channel_id", managedIds)
        .order("requested_at", { ascending: false }),
    ])
    : [{ data: [] as Record<string, unknown>[] }, { data: [] as Record<string, unknown>[] }];

  // Here the row's own user_id / target_user_id IS the other party: the
  // person who asked.
  const requesterProfiles = await fetchProfilesByUserId(supabaseAdmin, [
    ...new Set([
      ...(managedMembership ?? []).map((r) => r.user_id as string),
      ...(managedShares ?? []).map((r) => r.target_user_id as string),
    ]),
  ]);
  const managedRow = (r: Record<string, unknown>, kind: "membership" | "share", requester: string) => {
    const profile = requesterProfiles.get(requester);
    return {
      id: r.id,
      kind,
      channel_id: r.channel_id,
      channel_name: managedChannelName.get(r.channel_id as string) ?? null,
      counterpart_user_id: requester,
      counterpart_display_name: profile?.display_name ?? null,
      counterpart_avatar_url: profile?.avatar_url ?? null,
      ...(kind === "share" ? { space_id: r.space_id } : {}),
      direction: r.direction,
      status: r.status,
      requested_at: r.requested_at,
      decided_at: r.decided_at,
    };
  };

  return jsonResponse({
    membership_requests: membership,
    share_requests: shares,
    managed_membership_requests: (managedMembership ?? []).map((r) => managedRow(r, "membership", r.user_id as string)),
    managed_share_requests: (managedShares ?? []).map((r) => managedRow(r, "share", r.target_user_id as string)),
  });
});
