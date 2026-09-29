// What the caller could restore (migrations/0048): trashed Spaces they are
// the Administrator of, and trashed Channels of an active Space they
// manage. A Channel that is only gone because its whole Space is in the
// trash isn't listed separately -- restoring the Space brings it back.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { purgeAfter } from "../_shared/trash.ts";

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

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const [{ data: trashedSpaces }, { data: ownedActive }, { data: coOwned }] = await Promise.all([
    supabaseAdmin.from("spaces").select("id, name, deleted_at, deleted_by").eq("owner_id", userId).not("deleted_at", "is", null),
    supabaseAdmin.from("spaces").select("id").eq("owner_id", userId).is("deleted_at", null),
    supabaseAdmin.from("space_co_owners").select("space_id, spaces!inner(deleted_at)").eq("user_id", userId).is("spaces.deleted_at", null),
  ]);
  const managedActiveSpaceIds = [
    ...(ownedActive ?? []).map((s: { id: string }) => s.id),
    ...(coOwned ?? []).map((c: { space_id: string }) => c.space_id),
  ];
  const { data: trashedChannels } = managedActiveSpaceIds.length > 0
    ? await supabaseAdmin
      .from("channels")
      .select("id, name, deleted_at, deleted_by, spaces!channels_space_id_fkey(name)")
      .in("space_id", managedActiveSpaceIds)
      .not("deleted_at", "is", null)
    : { data: [] };

  const deleterIds = [
    ...(trashedSpaces ?? []).map((s: { deleted_by: string | null }) => s.deleted_by),
    ...(trashedChannels ?? []).map((c: { deleted_by: string | null }) => c.deleted_by),
  ].filter((id): id is string => Boolean(id));
  const profiles = await fetchProfilesByUserId(supabaseAdmin, [...new Set(deleterIds)]);
  const nameOf = (id: string | null) => (id ? profiles.get(id)?.display_name ?? null : null);

  return jsonResponse({
    spaces: (trashedSpaces ?? []).map((s) => ({
      id: s.id,
      name: s.name,
      deleted_at: s.deleted_at,
      deleted_by_name: nameOf(s.deleted_by as string | null),
      purge_after: purgeAfter(s.deleted_at as string),
    })),
    channels: (trashedChannels ?? []).map((c) => ({
      id: c.id,
      name: c.name,
      // deno-lint-ignore no-explicit-any
      space_name: (c.spaces as any)?.name ?? null,
      deleted_at: c.deleted_at,
      deleted_by_name: nameOf(c.deleted_by as string | null),
      purge_after: purgeAfter(c.deleted_at as string),
    })),
  });
});
