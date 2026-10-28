// A Frame's Frame-Admins (migrations/0089) with their profiles, plus -- for
// the Space's managers -- the invites not yet answered. Also tells the
// caller what they are here. An Edge Function because profiles have no
// cross-user RLS (see _shared/profiles.ts).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";

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

  let body: { frame_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.frame_id) return jsonResponse({ error: "frame_id_required" }, 400);

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: frame } = await admin.from("frames").select("id, space_id").eq("id", body.frame_id).maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);

  const [access, { data: adminRows }, { data: inviteRows }] = await Promise.all([
    resolveSpaceAccess(admin, frame.space_id, userId),
    admin.from("frame_admins").select("user_id, created_at").eq("frame_id", frame.id).order("created_at"),
    admin.from("frame_admin_invites").select("id, invitee_user_id, requested_at").eq("frame_id", frame.id).eq("status", "pending"),
  ]);
  const callerIsFrameAdmin = (adminRows ?? []).some((r) => r.user_id === userId);
  const managesSpace = access.manages || access.isStaff;
  if (!managesSpace && !callerIsFrameAdmin) return jsonResponse({ error: "forbidden" }, 403);

  const invites = managesSpace ? inviteRows ?? [] : [];
  const profiles = await fetchProfilesByUserId(admin, [
    ...(adminRows ?? []).map((r) => r.user_id as string),
    ...invites.map((r) => r.invitee_user_id as string),
  ]);
  const person = (id: string) => ({
    user_id: id,
    display_name: profiles.get(id)?.display_name ?? null,
    avatar_url: profiles.get(id)?.avatar_url ?? null,
  });

  return jsonResponse({
    frame_admins: (adminRows ?? []).map((r) => person(r.user_id as string)),
    pending_invites: invites.map((r) => ({ id: r.id, ...person(r.invitee_user_id as string) })),
    caller_manages_space: managesSpace,
    caller_is_frame_admin: callerIsFrameAdmin,
  });
});
