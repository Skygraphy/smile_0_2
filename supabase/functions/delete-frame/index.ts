// Deletes a Frame for good (decision 2026-10-06: the owner can delete
// everything, nothing lingers). Revoking stays as the reversible option.
//
// Who may: the Frame's Space Admin or a Co-Admin -- the people who manage
// it everywhere else. The row delete cascades to its album assignments and
// credentials. The Frame itself is woken right away with its own last FCM
// token (read before the row is gone -- afterwards nobody knows it): its
// next sync gets frame_not_found, it wipes its photos and shows the
// pairing screen again.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";
import { isSpaceOwnerOrCoOwner, spaceManagerIds } from "../_shared/space-access.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);

  let body: { frame_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.frame_id) return jsonResponse({ error: "frame_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { data: frame } = await supabaseAdmin
    .from("frames")
    .select("id, name, space_id, fcm_token, spaces(name)")
    .eq("id", body.frame_id)
    .maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);
  if (!(await isSpaceOwnerOrCoOwner(supabaseAdmin, frame.space_id as string, userData.user.id))) {
    return jsonResponse({ error: "not_space_manager" }, 403);
  }

  const { error } = await supabaseAdmin.from("frames").delete().eq("id", frame.id);
  if (error) return jsonResponse({ error: "delete_failed", detail: error.message }, 500);

  // The Space's other managers hear about it (0064).
  const actorId = userData.user.id;
  // deno-lint-ignore no-explicit-any
  const spaceName = (frame.spaces as any)?.name ?? "";
  const profiles = await fetchProfilesByUserId(supabaseAdmin, [actorId]);
  await pushNotificationToUsers(
    supabaseAdmin,
    (await spaceManagerIds(supabaseAdmin, frame.space_id as string)).filter((u) => u !== actorId),
    {
      title: "Frame gelöscht",
      body: `${profiles.get(actorId)?.display_name ?? "Jemand"} hat den Frame „${frame.name}“ in „${spaceName}“ gelöscht.`,
    },
    { type: "frame_changed", space_id: frame.space_id as string, space_name: spaceName },
  );

  if (frame.fcm_token) {
    try {
      await sendDataMessage(frame.fcm_token as string, { type: "sync", table: "frames", op: "delete" });
    } catch {
      // Best-effort: a Frame that is off right now finds out at its next sync.
    }
  }
  return jsonResponse({ status: "deleted" });
});
