// Powers space_co_owners_screen.dart's list. Pure read-side join the client
// can never do itself: space_co_owners is RLS-readable directly, but no
// policy anywhere exposes profiles across users (see _shared/profiles.ts).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { isSpaceOwnerOrCoOwner, isStaff as checkStaff } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  space_id: string;
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
  if (!body.space_id) return jsonResponse({ error: "space_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isStaff = await checkStaff(supabaseAdmin, userId);

  const { data: space } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", body.space_id).maybeSingle();
  if (!space) return jsonResponse({ error: "space_not_found" }, 404);
  if (!isStaff && !(await isSpaceOwnerOrCoOwner(supabaseAdmin, body.space_id, userId))) {
    return jsonResponse({ error: "not_space_owner" }, 403);
  }

  const isCallerFounder = space.owner_id === userId;

  const [{ data: coOwnerRows, error: fetchError }, { data: pendingInviteRows }] = await Promise.all([
    supabaseAdmin.from("space_co_owners").select("user_id, created_at").eq("space_id", body.space_id).order("created_at"),
    // Only meaningful to the founder (who invited whom) -- fetched
    // regardless so a co-owner's response just comes back empty, rather
    // than a second round trip once we know the role.
    supabaseAdmin
      .from("space_co_owner_invites")
      .select("id, invitee_user_id, requested_at")
      .eq("space_id", body.space_id)
      .eq("status", "pending")
      .order("requested_at"),
  ]);
  if (fetchError) return jsonResponse({ error: "fetch_failed" }, 500);

  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, [
    space.owner_id as string,
    ...(coOwnerRows ?? []).map((r) => r.user_id as string),
    ...(pendingInviteRows ?? []).map((r) => r.invitee_user_id as string),
  ]);

  const founderProfile = profilesByUserId.get(space.owner_id as string);
  const coOwners = (coOwnerRows ?? []).map((r) => {
    const profile = profilesByUserId.get(r.user_id as string);
    return {
      user_id: r.user_id,
      display_name: profile?.display_name ?? null,
      avatar_url: profile?.avatar_url ?? null,
      created_at: r.created_at,
    };
  });
  const pendingInvites = isCallerFounder
    ? (pendingInviteRows ?? []).map((r) => {
        const profile = profilesByUserId.get(r.invitee_user_id as string);
        return {
          id: r.id,
          invitee_user_id: r.invitee_user_id,
          display_name: profile?.display_name ?? null,
          avatar_url: profile?.avatar_url ?? null,
          requested_at: r.requested_at,
        };
      })
    : [];

  return jsonResponse({
    founder_user_id: space.owner_id,
    founder_display_name: founderProfile?.display_name ?? null,
    founder_avatar_url: founderProfile?.avatar_url ?? null,
    co_owners: coOwners,
    pending_invites: pendingInvites,
    caller_is_founder: isCallerFounder,
  });
});
