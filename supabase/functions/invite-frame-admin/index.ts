// The Space's Admin or a Co-Admin invites a person to become Frame-Admin of
// one Frame (migrations/0089_frame_admins.sql) -- by name (user_id) or
// email. Like every connection in this app: one side proposes, the invitee
// decides (frame_admin_invites_invitee_decide).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";
import { isFrameAdmin } from "../_shared/frame-admin.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  frame_id: string;
  email?: string;
  user_id?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.frame_id || (!body.email && !body.user_id)) return jsonResponse({ error: "frame_id_and_person_required" }, 400);

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: frame } = await admin
    .from("frames")
    .select("id, name, space_id, lifecycle_state")
    .eq("id", body.frame_id)
    .maybeSingle();
  if (!frame || frame.lifecycle_state === "revoked") return jsonResponse({ error: "frame_not_found" }, 404);
  const access = await resolveSpaceAccess(admin, frame.space_id, userId);
  if (!access.manages && !access.isStaff) return jsonResponse({ error: "not_space_manager" }, 403);

  const inviteeId = body.user_id ?? (await findUserIdByEmail(admin, body.email!));
  if (!inviteeId) return jsonResponse({ error: "user_not_found" }, 404);
  // Whoever manages the Space may do all of this already.
  if ((await resolveSpaceAccess(admin, frame.space_id, inviteeId)).manages) return jsonResponse({ status: "already_frame_admin" });
  if (await isFrameAdmin(admin, frame.id, inviteeId)) return jsonResponse({ status: "already_frame_admin" });

  const { data: invite, error: insertError } = await admin
    .from("frame_admin_invites")
    .insert({ frame_id: frame.id, invitee_user_id: inviteeId })
    .select("id")
    .maybeSingle();
  if (insertError) {
    if (insertError.message.includes("uq_frame_admin_invites_pending")) return jsonResponse({ error: "invite_already_pending" }, 409);
    return jsonResponse({ error: "invite_failed", detail: insertError.message }, 500);
  }

  const inviter = (await fetchProfilesByUserId(admin, [userId])).get(userId)?.display_name ?? null;
  await pushNotificationToUsers(
    admin,
    [inviteeId],
    (t) => t.frameAdminInvite({ inviter, frame: frame.name }),
    { type: "frame_admin_invite", frame_id: frame.id, frame_name: frame.name },
  );

  return jsonResponse({ status: "invited", invite_id: invite?.id });
});
