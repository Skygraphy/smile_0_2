// Powers groups_screen.dart's read-only "Mitglied in" section. Groups are
// deliberately private to their owner (groups/group_members RLS is fully
// owner-scoped, see migrations/0020_groups.sql) -- a member has no RLS
// path to even see the group's own name, let alone which channels it
// grants. Without this, a member added to a group has no way to find out
// why they suddenly have access to a channel, or that the group exists at
// all. Read-only: no management capability is exposed here, only visibility
// into the caller's own memberships.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: memberRows, error: memberError } = await supabaseAdmin
    .from("group_members")
    .select("group_id")
    .eq("user_id", userId);
  if (memberError) return jsonResponse({ error: "fetch_failed" }, 500);

  const groupIds = (memberRows ?? []).map((r) => r.group_id as string);
  if (groupIds.length === 0) return jsonResponse({ memberships: [] });

  const { data: groups } = await supabaseAdmin.from("groups").select("id, name, owner_id").in("id", groupIds);

  const { data: grants } = await supabaseAdmin
    .from("group_channel_grants")
    .select("group_id, channel_id, channels(name, spaces(name))")
    .in("group_id", groupIds);

  const channelsByGroup = new Map<string, { channel_id: string; channel_name: string; space_name: string }[]>();
  for (const g of grants ?? []) {
    // deno-lint-ignore no-explicit-any
    const channel = g.channels as any;
    const list = channelsByGroup.get(g.group_id as string) ?? [];
    list.push({
      channel_id: g.channel_id as string,
      channel_name: channel?.name ?? null,
      space_name: channel?.spaces?.name ?? null,
    });
    channelsByGroup.set(g.group_id as string, list);
  }

  const memberships = await Promise.all(
    (groups ?? []).map(async (group) => {
      const { data: ownerRecord } = await supabaseAdmin.auth.admin.getUserById(group.owner_id as string);
      return {
        group_id: group.id,
        group_name: group.name,
        owner_email: ownerRecord?.user?.email ?? null,
        channels: channelsByGroup.get(group.id as string) ?? [],
      };
    }),
  );

  return jsonResponse({ memberships });
});
