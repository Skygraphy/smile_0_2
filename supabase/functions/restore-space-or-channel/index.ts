// Takes a Channel or Space back out of the 30-day trash (migrations/0048).
// Everything comes back exactly as it was -- members, shares, Frames and
// their assignments, photos -- since trashing only ever set deleted_at.
//
// Who may: the same people who may trash it -- a Channel: its (active)
// home Space's Administrator or co-owners; a Space: its Administrator.
// A Channel whose whole Space is in the trash comes back with the Space.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";

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
  const userId = userData.user.id;

  let body: { kind: "channel" | "space"; id: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if ((body.kind !== "channel" && body.kind !== "space") || !body.id) {
    return jsonResponse({ error: "kind_and_id_required" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  if (body.kind === "channel") {
    const { data: channel } = await supabaseAdmin.from("channels").select("space_id, deleted_at").eq("id", body.id).maybeSingle();
    if (!channel || !channel.deleted_at) return jsonResponse({ error: "not_in_trash" }, 404);
    const space = await resolveSpaceAccess(supabaseAdmin, channel.space_id as string, userId);
    if (!space.active) return jsonResponse({ error: "space_in_trash" }, 409);
    if (!space.manages) return jsonResponse({ error: "forbidden" }, 403);
  } else {
    const space = await resolveSpaceAccess(supabaseAdmin, body.id, userId);
    if (!space.exists || space.active) return jsonResponse({ error: "not_in_trash" }, 404);
    if (!space.isAdmin) return jsonResponse({ error: "only_administrator" }, 403);
  }

  const { error } = await supabaseAdmin
    .from(body.kind === "channel" ? "channels" : "spaces")
    .update({ deleted_at: null, deleted_by: null })
    .eq("id", body.id);
  if (error) return jsonResponse({ error: "restore_failed", detail: error.message }, 500);

  await supabaseAdmin.rpc("emit_event", {
    kind: "restored",
    payload: { kind: body.kind, id: body.id, actor_id: userId },
  });
  return jsonResponse({ status: "restored" });
});
