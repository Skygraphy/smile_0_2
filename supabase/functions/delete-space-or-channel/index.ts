// Moves a whole Channel or Space to the TRASH (decision 2026-09-29,
// migrations/0048_trash.sql): invisible to everyone at once -- the access_*
// functions treat trashed rows as not there -- but nothing is destroyed.
// Everyone affected is notified (notify-event 'trashed'); the people who
// manage it can undo it for 30 days (restore-space-or-channel); only then
// does purge-trash delete it for good, photo files included.
//
// Who may:
// - a Channel: its home Space's Administrator or a co-owner -- the same
//   people who already manage everything else about it.
// - a Space: ONLY its Administrator. Co-owners are equal in what they can
//   do inside the Space, but never get to end it.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";
import { TRASH_DAYS } from "../_shared/trash.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  kind: "channel" | "space";
  id: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
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
  if ((body.kind !== "channel" && body.kind !== "space") || !body.id) {
    return jsonResponse({ error: "kind_and_id_required" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  if (body.kind === "channel") {
    const access = await resolveChannelAccess(supabaseAdmin, body.id, userId);
    if (!access.exists || !access.active) return jsonResponse({ error: "not_found" }, 404);
    if (!access.isSco) return jsonResponse({ error: "forbidden" }, 403);
  } else {
    const space = await resolveSpaceAccess(supabaseAdmin, body.id, userId);
    if (!space.exists || !space.active) return jsonResponse({ error: "not_found" }, 404);
    if (!space.isAdmin) return jsonResponse({ error: "only_administrator" }, 403);
  }

  const deletedAt = new Date();
  const { error: trashError } = await supabaseAdmin
    .from(body.kind === "channel" ? "channels" : "spaces")
    .update({ deleted_at: deletedAt.toISOString(), deleted_by: userId })
    .eq("id", body.id)
    .is("deleted_at", null);
  if (trashError) return jsonResponse({ error: "delete_failed", detail: trashError.message }, 500);

  await supabaseAdmin.rpc("emit_event", {
    kind: "trashed",
    payload: { kind: body.kind, id: body.id, actor_id: userId },
  });

  const purgeAfter = new Date(deletedAt.getTime() + TRASH_DAYS * 24 * 3600 * 1000);
  return jsonResponse({ status: "trashed", purge_after: purgeAfter.toISOString() });
});
