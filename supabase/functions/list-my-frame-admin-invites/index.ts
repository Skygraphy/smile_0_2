// The caller's own open Frame-Admin invites (migrations/0089), with the
// Frame's name and who invited -- the invitee cannot read either via RLS yet.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: invites, error } = await admin
    .from("frame_admin_invites")
    .select("id, frame_id, requested_at, frames!inner(name, lifecycle_state, spaces!inner(name, owner_id, deleted_at))")
    .eq("invitee_user_id", userId)
    .eq("status", "pending")
    .order("requested_at", { ascending: false });
  if (error) return jsonResponse({ error: "fetch_failed" }, 500);

  // deno-lint-ignore no-explicit-any
  const open = (invites ?? []).filter((i: any) => i.frames.lifecycle_state !== "revoked" && !i.frames.spaces.deleted_at);
  // deno-lint-ignore no-explicit-any
  const profiles = await fetchProfilesByUserId(admin, open.map((i: any) => i.frames.spaces.owner_id as string));
  return jsonResponse({
    // deno-lint-ignore no-explicit-any
    invites: open.map((i: any) => ({
      id: i.id,
      frame_id: i.frame_id,
      frame_name: i.frames.name,
      space_name: i.frames.spaces.name,
      inviter_display_name: profiles.get(i.frames.spaces.owner_id)?.display_name ?? null,
      inviter_avatar_url: profiles.get(i.frames.spaces.owner_id)?.avatar_url ?? null,
      requested_at: i.requested_at,
    })),
  });
});
