// "Darf Alben anlegen" by invitation (2026-11-19, migrations/0110): the
// Space's Admin or a Co-Admin invites a known person; the person accepts or
// declines in Neuigkeiten (plain RLS-governed PATCH on
// space_album_creator_invites), only then the right exists. Mirrors
// invite-space-co-owner, but managers (not only the founder) may invite.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { resolveSpaceAccess, isStaff as checkStaff } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  space_id: string;
  email?: string;
  // By name (2026-10-11): a person from known_people() instead of an email.
  user_id?: string;
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
  if (!body.space_id || (!body.email && !body.user_id)) return jsonResponse({ error: "space_id_and_email_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isStaff = await checkStaff(supabaseAdmin, userId);

  const { data: space } = await supabaseAdmin.from("spaces").select("id, name, owner_id").eq("id", body.space_id).maybeSingle();
  if (!space) return jsonResponse({ error: "space_not_found" }, 404);
  if (!isStaff && !(await resolveSpaceAccess(supabaseAdmin, body.space_id, userId)).manages) return jsonResponse({ error: "not_space_manager" }, 403);

  const inviteeId = body.user_id ?? (await findUserIdByEmail(supabaseAdmin, body.email!));
  if (!inviteeId) return jsonResponse({ error: "user_not_found" }, 404);
  // Admin and Co-Admins create albums anyway.
  if ((await resolveSpaceAccess(supabaseAdmin, body.space_id, inviteeId)).manages) return jsonResponse({ error: "already_manager" }, 409);
  const { data: existing } = await supabaseAdmin
    .from("space_album_creators")
    .select("user_id")
    .eq("space_id", body.space_id)
    .eq("user_id", inviteeId)
    .maybeSingle();
  if (existing) return jsonResponse({ status: "already_album_creator" });

  const { data: invite, error: insertError } = await supabaseAdmin
    .from("space_album_creator_invites")
    .insert({ space_id: body.space_id, invitee_user_id: inviteeId, invited_by: userId })
    .select()
    .maybeSingle();
  if (insertError) {
    if (insertError.message.includes("uq_album_creator_invites_pending")) {
      return jsonResponse({ error: "invite_already_pending" }, 409);
    }
    return jsonResponse({ error: "invite_failed", detail: insertError.message }, 500);
  }

  const { data: me } = await supabaseAdmin.from("profiles").select("display_name").eq("user_id", userId).maybeSingle();
  await pushNotificationToUsers(
    supabaseAdmin,
    [inviteeId],
    (t) => t.albumCreatorInvite({ actor: (me?.display_name as string | undefined) ?? null, space: space.name }),
    { type: "album_creator_invite", space_id: body.space_id, space_name: space.name },
  );

  return jsonResponse({ status: "invited", invite_id: invite?.id });
});
