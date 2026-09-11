// Powers channel_members_screen.dart's "Beitrittsanfragen" section.
// Mirrors list-channel-members almost exactly (same reason: no
// client-facing RLS resolves auth.users.email), just scoped to pending
// channel_join_requests instead of channel_memberships.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

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

  const { data: channel } = await supabaseAdmin.from("channels").select("space_id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  const { data: ownerRow } = await supabaseAdmin
    .from("space_owners")
    .select("id")
    .eq("space_id", channel.space_id)
    .eq("user_id", userId)
    .maybeSingle();

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

  const resolved = await Promise.all(
    (requests ?? []).map(async (r) => {
      const { data: userRecord } = await supabaseAdmin.auth.admin.getUserById(r.user_id as string);
      return {
        id: r.id,
        user_id: r.user_id,
        email: userRecord?.user?.email ?? null,
        requested_at: r.requested_at,
      };
    }),
  );

  return jsonResponse({ requests: resolved });
});
