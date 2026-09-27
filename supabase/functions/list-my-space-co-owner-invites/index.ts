// The caller's own pending Space co-owner invites (migrations/0038_space_co_owner_invites.sql).
// Needed as a service-role function for the same reason list-my-invites is:
// the invitee genuinely cannot see the Space's own name or the founder's
// profile yet via plain RLS (spaces_select requires already being the
// founder or a co-owner; profiles has no cross-user RLS at all, see
// _shared/profiles.ts) -- without this they'd have to accept blind.
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

  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: invites, error: fetchError } = await supabaseAdmin
    .from("space_co_owner_invites")
    .select("id, space_id, status, requested_at")
    .eq("invitee_user_id", userId)
    .eq("status", "pending")
    .order("requested_at", { ascending: false });
  if (fetchError) return jsonResponse({ error: "fetch_failed" }, 500);

  const spaceIds = [...new Set((invites ?? []).map((i) => i.space_id as string))];
  const { data: spaceRows } = spaceIds.length > 0
    ? await supabaseAdmin.from("spaces").select("id, name, owner_id").in("id", spaceIds)
    : { data: [] as { id: string; name: string; owner_id: string }[] };
  const spaceById = new Map((spaceRows ?? []).map((s) => [s.id as string, s]));

  const profilesByUserId = await fetchProfilesByUserId(
    supabaseAdmin,
    (spaceRows ?? []).map((s) => s.owner_id as string),
  );

  const result = (invites ?? []).map((i) => {
    const space = spaceById.get(i.space_id as string);
    const founderProfile = space ? profilesByUserId.get(space.owner_id as string) : undefined;
    return {
      id: i.id,
      space_id: i.space_id,
      space_name: space?.name ?? null,
      founder_display_name: founderProfile?.display_name ?? null,
      founder_avatar_url: founderProfile?.avatar_url ?? null,
      requested_at: i.requested_at,
    };
  });

  return jsonResponse({ invites: result });
});
