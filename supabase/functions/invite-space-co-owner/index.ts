// Called by a Space's founder to invite a known person (by email) to
// become a co-owner (migrations/0037_space_co_owners.sql,
// migrations/0038_space_co_owner_invites.sql). Consistent with every other
// connection this app creates -- the founder proposes, the invitee decides
// via a plain RLS-governed PATCH (space_co_owner_invites_invitee_decide
// already allows exactly that) -- unlike this function's short-lived
// predecessor (add-space-co-owner), which granted co-owner status
// directly with no say from the recipient at all. See the migration's
// header comment for why that was wrong: taking on real administrative
// power over someone else's household Space isn't something to have
// thrust on you.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { resolveSpaceAccess, isStaff as checkStaff } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  space_id: string;
  email: string;
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
  if (!body.space_id || !body.email) return jsonResponse({ error: "space_id_and_email_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isStaff = await checkStaff(supabaseAdmin, userId);

  const { data: space } = await supabaseAdmin.from("spaces").select("id, name, owner_id").eq("id", body.space_id).maybeSingle();
  if (!space) return jsonResponse({ error: "space_not_found" }, 404);
  // Only the founder may invite -- not a co-owner, see the migration's
  // header comment on space_co_owner_invites_founder_insert.
  if (!isStaff && !(await resolveSpaceAccess(supabaseAdmin, body.space_id, userId)).isAdmin) return jsonResponse({ error: "not_space_founder" }, 403);

  const inviteeId = await findUserIdByEmail(supabaseAdmin, body.email);
  if (!inviteeId) return jsonResponse({ error: "user_not_found" }, 404);
  if (inviteeId === space.owner_id) return jsonResponse({ error: "already_founder" }, 409);

  const { data: existingCoOwner } = await supabaseAdmin
    .from("space_co_owners")
    .select("user_id")
    .eq("space_id", body.space_id)
    .eq("user_id", inviteeId)
    .maybeSingle();
  if (existingCoOwner) return jsonResponse({ status: "already_co_owner" });

  const { data: invite, error: insertError } = await supabaseAdmin
    .from("space_co_owner_invites")
    .insert({ space_id: body.space_id, invitee_user_id: inviteeId })
    .select()
    .maybeSingle();
  if (insertError) {
    if (insertError.message.includes("uq_space_co_owner_invites_pending")) {
      return jsonResponse({ error: "invite_already_pending" }, 409);
    }
    return jsonResponse({ error: "invite_failed", detail: insertError.message }, 500);
  }

  await pushNotificationToUsers(
    supabaseAdmin,
    [inviteeId],
    { title: "Einladung zur Verwaltung", body: `Du wurdest eingeladen, den Space "${space.name}" mitzuverwalten.` },
    { type: "space_co_owner_invite", space_id: body.space_id, space_name: space.name },
  );

  return jsonResponse({ status: "invited", invite_id: invite?.id });
});
