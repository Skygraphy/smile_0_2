// Called from group_detail_screen.dart's "+ Person hinzufügen" -- the
// client only has an email address, but group_members needs a user_id, and
// no client-facing RLS ever exposes the auth.users id<->email mapping.
// Only the group's owner (or staff) may add a member (mirrors the
// groups/group_members RLS, defense in depth).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const USERS_PER_PAGE = 200;
const MAX_PAGES = 25; // 5000 users -- comfortably more than this app's user base

interface RequestBody {
  group_id: string;
  email: string;
}

// deno-lint-ignore no-explicit-any
async function findUserIdByEmail(supabaseAdmin: any, email: string): Promise<string | null> {
  const target = email.trim().toLowerCase();
  for (let page = 1; page <= MAX_PAGES; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: USERS_PER_PAGE });
    if (error || !data) return null;
    // deno-lint-ignore no-explicit-any
    const match = data.users.find((u: any) => u.email?.toLowerCase() === target);
    if (match) return match.id;
    if (data.users.length < USERS_PER_PAGE) return null; // last page, no match
  }
  return null;
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
  if (!body.group_id || !body.email) return jsonResponse({ error: "group_id_and_email_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: group } = await supabaseAdmin.from("groups").select("owner_id").eq("id", body.group_id).maybeSingle();
  if (!group) return jsonResponse({ error: "group_not_found" }, 404);
  if (!isStaff && group.owner_id !== userId) return jsonResponse({ error: "not_group_owner" }, 403);

  const memberUserId = await findUserIdByEmail(supabaseAdmin, body.email);
  if (!memberUserId) return jsonResponse({ error: "user_not_found" }, 404);

  const { data: existing } = await supabaseAdmin
    .from("group_members")
    .select("id")
    .eq("group_id", body.group_id)
    .eq("user_id", memberUserId)
    .maybeSingle();
  if (existing) return jsonResponse({ status: "already_member" });

  const { error: insertError } = await supabaseAdmin
    .from("group_members")
    .insert({ group_id: body.group_id, user_id: memberUserId });
  if (insertError) return jsonResponse({ error: "add_failed", detail: insertError.message }, 500);

  return jsonResponse({ status: "added", user_id: memberUserId, email: body.email });
});
