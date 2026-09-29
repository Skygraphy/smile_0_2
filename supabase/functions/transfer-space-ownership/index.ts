// Called by a Space's founder to voluntarily hand the founder role itself
// to one of their existing co-owners (migrations/0037_space_co_owners.sql)
// -- the "I'm stepping down" half of the WhatsApp-admin-handover analogy;
// the other half (the founder's account being deleted outright) is handled
// automatically by that migration's `handle_space_owner_removal` trigger,
// not this function.
//
// The outgoing founder becomes a plain co-owner afterward (keeps full
// access, just loses the "only I can add/remove co-owners" power) rather
// than losing access outright -- same as a WhatsApp admin who demotes
// themselves is still a member, not removed from the group.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { resolveSpaceAccess, isStaff as checkStaff } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  space_id: string;
  new_owner_user_id: string;
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
  if (!body.space_id || !body.new_owner_user_id) return jsonResponse({ error: "space_id_and_new_owner_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isStaff = await checkStaff(supabaseAdmin, userId);

  const { data: space } = await supabaseAdmin.from("spaces").select("id, name, owner_id").eq("id", body.space_id).maybeSingle();
  if (!space) return jsonResponse({ error: "space_not_found" }, 404);
  if (!isStaff && !(await resolveSpaceAccess(supabaseAdmin, body.space_id, userId)).isAdmin) return jsonResponse({ error: "not_space_founder" }, 403);

  const { data: coOwnerRow } = await supabaseAdmin
    .from("space_co_owners")
    .select("user_id")
    .eq("space_id", body.space_id)
    .eq("user_id", body.new_owner_user_id)
    .maybeSingle();
  if (!coOwnerRow) return jsonResponse({ error: "not_a_co_owner" }, 400);

  const { error: updateError } = await supabaseAdmin
    .from("spaces")
    .update({ owner_id: body.new_owner_user_id })
    .eq("id", body.space_id);
  if (updateError) return jsonResponse({ error: "transfer_failed", detail: updateError.message }, 500);

  // The new founder is no longer just a co-owner; the outgoing founder
  // takes their place in that list instead, so they keep full access.
  await supabaseAdmin
    .from("space_co_owners")
    .delete()
    .eq("space_id", body.space_id)
    .eq("user_id", body.new_owner_user_id);
  // Best-effort: the transfer itself already succeeded above regardless of
  // whether this insert succeeds (e.g. if the row somehow already exists).
  await supabaseAdmin.from("space_co_owners").insert({ space_id: body.space_id, user_id: space.owner_id });

  await pushNotificationToUsers(
    supabaseAdmin,
    [body.new_owner_user_id],
    { title: "Neue Administrator-Rolle", body: `Du bist jetzt Administrator des Space "${space.name}".` },
    { type: "space_ownership_transferred", space_id: body.space_id, space_name: space.name },
  );

  return jsonResponse({ status: "transferred" });
});
