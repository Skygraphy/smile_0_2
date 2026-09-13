// Powers channel_members_screen.dart's "Beitrittsanfragen" section.
// Mirrors list-channel-members almost exactly (same reason: no
// client-facing RLS resolves auth.users.email), just scoped to pending
// channel_join_requests instead of channel_memberships.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id: string;
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

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.channel_id) return jsonResponse({ error: "channel_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: channel } = await supabaseAdmin.from("channels").select("id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  // A channel can be linked to more than one Space now -- an owner of
  // *any* linked Space may administer join requests, same as any other
  // channel-admin-equivalent action.
  const { data: spaceLinks } = await supabaseAdmin.from("space_channels").select("space_id").eq("channel_id", body.channel_id);
  const linkedSpaceIds = (spaceLinks ?? []).map((l) => l.space_id as string);

  const { data: ownerRows } = linkedSpaceIds.length > 0
    ? await supabaseAdmin.from("space_owners").select("id").in("space_id", linkedSpaceIds).eq("user_id", userId)
    : { data: [] as { id: string }[] };
  const ownerRow = (ownerRows ?? []).length > 0 ? ownerRows![0] : null;

  const { data: membership } = await supabaseAdmin
    .from("channel_memberships")
    .select("role")
    .eq("channel_id", body.channel_id)
    .eq("user_id", userId)
    .maybeSingle();

  const isChannelAdmin = isStaff || Boolean(ownerRow) || membership?.role === "channel_admin";
  if (!isChannelAdmin) return jsonResponse({ error: "not_a_channel_admin" }, 403);

  const { data: requests, error: requestsError } = await supabaseAdmin
    .from("channel_join_requests")
    .select("id, user_id, requested_at")
    .eq("channel_id", body.channel_id)
    .eq("status", "pending")
    .order("requested_at");
  if (requestsError) return jsonResponse({ error: "fetch_failed" }, 500);

  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, (requests ?? []).map((r) => r.user_id as string));

  const resolved = await Promise.all(
    (requests ?? []).map(async (r) => {
      const { data: userRecord } = await supabaseAdmin.auth.admin.getUserById(r.user_id as string);
      const profile = profilesByUserId.get(r.user_id as string);
      return {
        id: r.id,
        user_id: r.user_id,
        email: userRecord?.user?.email ?? null,
        display_name: profile?.display_name ?? null,
        avatar_url: profile?.avatar_url ?? null,
        requested_at: r.requested_at,
      };
    }),
  );

  return jsonResponse({ requests: resolved });
});
