// Powers group_detail_screen.dart's member list. Same reason as
// list-channel-members: no client-facing RLS ever exposes auth.users.email,
// so resolving it needs the service-role key. Authorization mirrors, not
// replaces, the groups/group_members RLS (defense in depth): only the
// group's owner (or staff) may list its members.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  group_id: string;
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
  if (!body.group_id) return jsonResponse({ error: "group_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: group } = await supabaseAdmin.from("groups").select("owner_id").eq("id", body.group_id).maybeSingle();
  if (!group) return jsonResponse({ error: "group_not_found" }, 404);
  if (!isStaff && group.owner_id !== userId) return jsonResponse({ error: "not_group_owner" }, 403);

  const { data: members, error: membersError } = await supabaseAdmin
    .from("group_members")
    .select("id, user_id, created_at")
    .eq("group_id", body.group_id)
    .order("created_at");
  if (membersError) return jsonResponse({ error: "fetch_failed" }, 500);

  const resolved = await Promise.all(
    (members ?? []).map(async (m) => {
      const { data: userRecord } = await supabaseAdmin.auth.admin.getUserById(m.user_id as string);
      return {
        id: m.id,
        user_id: m.user_id,
        email: userRecord?.user?.email ?? null,
        created_at: m.created_at,
      };
    }),
  );

  return jsonResponse({ members: resolved });
});
