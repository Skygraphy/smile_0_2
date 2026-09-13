// Powers channel_members_screen.dart's "Bestehendes Mitglied hinzufügen"
// picker: candidates are people already in some *other* channel of the same
// Space, not yet in the target channel. Space Owner (or staff) only --
// deliberately not open to a plain channel admin, since listing another
// channel's roster would violate the resource-isolation guarantee 0009
// documents ("a channel member can never see who belongs to... another
// channel of the same space"); the Space Owner is the one role already
// exempt from that boundary everywhere else in the schema.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  space_id: string;
  exclude_channel_id?: string;
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
  if (!body.space_id) return jsonResponse({ error: "space_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: ownerRow } = await supabaseAdmin
    .from("space_owners")
    .select("id")
    .eq("space_id", body.space_id)
    .eq("user_id", userId)
    .maybeSingle();

  if (!isStaff && !ownerRow) return jsonResponse({ error: "not_space_owner" }, 403);

  const { data: links } = await supabaseAdmin.from("space_channels").select("channel_id").eq("space_id", body.space_id);
  const channelIds = (links ?? []).map((l) => l.channel_id as string);
  if (channelIds.length === 0) return jsonResponse({ candidates: [] });

  const { data: memberships, error: membersError } = await supabaseAdmin
    .from("channel_memberships")
    .select("user_id, channel_id")
    .in("channel_id", channelIds)
    .neq("role", "device");
  if (membersError) return jsonResponse({ error: "fetch_failed" }, 500);

  const excludedUserIds = new Set(
    (memberships ?? []).filter((m) => m.channel_id === body.exclude_channel_id).map((m) => m.user_id as string),
  );
  const candidateUserIds = [
    ...new Set((memberships ?? []).map((m) => m.user_id as string).filter((id) => !excludedUserIds.has(id))),
  ];

  const profilesByUserId = await fetchProfilesByUserId(supabaseAdmin, candidateUserIds);

  const candidates = await Promise.all(
    candidateUserIds.map(async (id) => {
      const { data: userRecord } = await supabaseAdmin.auth.admin.getUserById(id);
      const profile = profilesByUserId.get(id);
      return {
        user_id: id,
        email: userRecord?.user?.email ?? null,
        display_name: profile?.display_name ?? null,
        avatar_url: profile?.avatar_url ?? null,
      };
    }),
  );

  return jsonResponse({ candidates });
});
