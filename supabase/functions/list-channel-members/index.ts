// Powers channel_members_screen.dart's roster. Pure read-side join that the
// client can never do itself: channel_memberships is RLS-readable directly,
// but no policy anywhere exposes auth.users.email (0009's header comment is
// explicit that content-bearing tables are the only ones with client RLS at
// all). The permission check below mirrors, rather than replaces,
// channel_memberships_select's own predicate -- defense in depth, not a new
// authorization surface.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id: string;
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
  if (!body.channel_id) return jsonResponse({ error: "channel_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: channel } = await supabaseAdmin.from("channels").select("id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  // A channel can be linked to more than one Space now (space_channels) --
  // an owner of *any* linked Space gets the same admin-equivalent power a
  // single-space owner always had, consistent with sharing being meant to
  // give both households real, symmetric control.
  const { data: spaceLinks } = await supabaseAdmin
    .from("space_channels")
    .select("spaces(id, name)")
    .eq("channel_id", body.channel_id);
  const linkedSpaces = (spaceLinks ?? [])
    // deno-lint-ignore no-explicit-any
    .map((row) => row.spaces as any)
    .filter(Boolean)
    .map((s) => ({ id: s.id as string, name: s.name as string }));
  const linkedSpaceIds = linkedSpaces.map((s) => s.id);

  const { data: ownerRows } = linkedSpaceIds.length > 0
    ? await supabaseAdmin.from("space_owners").select("id").in("space_id", linkedSpaceIds).eq("user_id", userId)
    : { data: [] as { id: string }[] };
  const ownerRow = (ownerRows ?? []).length > 0 ? ownerRows![0] : null;

  const { data: membership } = await supabaseAdmin
    .from("channel_memberships")
    .select("role")
    .eq("channel_id", body.channel_id)
    .eq("user_id", userId)
    .maybeSingle();

  const allowed = isStaff || Boolean(ownerRow) || Boolean(membership);
  if (!allowed) return jsonResponse({ error: "not_a_channel_member" }, 403);

  const isChannelAdmin = isStaff || Boolean(ownerRow) || membership?.role === "channel_admin";
  const isSpaceOwner = isStaff || Boolean(ownerRow);

  const { data: memberships, error: membersError } = await supabaseAdmin
    .from("channel_memberships")
    // via_group_id is a plain provenance marker (Phase 6b, see
    // migrations/0020_groups.sql) -- null for a direct/manual membership,
    // set when a group grant is what put this row here.
    .select("id, user_id, role, created_at, via_group_id")
    .eq("channel_id", body.channel_id)
    .neq("role", "device")
    .order("created_at");
  if (membersError) return jsonResponse({ error: "fetch_failed" }, 500);

  const groupIds = [...new Set((memberships ?? []).map((m) => m.via_group_id).filter(Boolean))] as string[];
  const groupNameById = new Map<string, string>();
  if (groupIds.length > 0) {
    const { data: groupRows } = await supabaseAdmin.from("groups").select("id, name").in("id", groupIds);
    for (const g of groupRows ?? []) groupNameById.set(g.id as string, g.name as string);
  }

  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, (memberships ?? []).map((m) => m.user_id as string));

  const members = await Promise.all(
    (memberships ?? []).map(async (m) => {
      const { data: userRecord } = await supabaseAdmin.auth.admin.getUserById(m.user_id as string);
      const profile = profilesByUserId.get(m.user_id as string);
      return {
        membership_id: m.id,
        user_id: m.user_id,
        email: userRecord?.user?.email ?? null,
        display_name: profile?.display_name ?? null,
        avatar_url: profile?.avatar_url ?? null,
        role: m.role,
        created_at: m.created_at,
        via_group_name: m.via_group_id ? groupNameById.get(m.via_group_id as string) ?? null : null,
      };
    }),
  );

  return jsonResponse({
    members,
    spaces: linkedSpaces,
    caller_is_admin: isChannelAdmin,
    caller_is_space_owner: isSpaceOwner,
  });
});
