// Powers channel_members_screen.dart's roster. Pure read-side join the
// client can never do itself: channel_members is RLS-readable directly,
// but no policy anywhere exposes profiles across users (see
// _shared/profiles.ts) or the channel's home/shared Space names beyond
// what the caller's own view already allows.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";

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

  const access = await resolveChannelAccess(supabaseAdmin, body.channel_id, userId);
  if (!access.exists) return jsonResponse({ error: "channel_not_found" }, 404);
  if (!access.canView) return jsonResponse({ error: "not_a_channel_member" }, 403);

  const { data: memberships, error: membersError } = await supabaseAdmin
    .from("channel_members")
    .select("user_id, created_at")
    .eq("channel_id", body.channel_id)
    .order("created_at");
  if (membersError) return jsonResponse({ error: "fetch_failed" }, 500);

  const { data: shareRows } = await supabaseAdmin
    .from("channel_shares")
    .select("space_id, spaces(id, name)")
    .eq("channel_id", body.channel_id);
  const sharedSpaces = (shareRows ?? [])
    // deno-lint-ignore no-explicit-any
    .map((row) => row.spaces as any)
    .filter(Boolean)
    .map((s) => ({ id: s.id as string, name: s.name as string }));

  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, (memberships ?? []).map((m) => m.user_id as string));

  const members = (memberships ?? []).map((m) => {
    const profile = profilesByUserId.get(m.user_id as string);
    return {
      user_id: m.user_id,
      display_name: profile?.display_name ?? null,
      avatar_url: profile?.avatar_url ?? null,
      created_at: m.created_at,
    };
  });

  return jsonResponse({
    members,
    shared_spaces: sharedSpaces,
    caller_is_sco: access.isSco,
  });
});
