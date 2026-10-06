// Deletes the caller's own account and everything of it (decision
// 2026-10-06: "alles wird gelöscht", nothing may linger):
// - Spaces they are Admin of: handed to their longest-standing Co-Admin
//   (the existing on_auth_user_deleted_handover_spaces trigger, 0037) -- or,
//   with no Co-Admin, deleted outright with all albums, photos and Frames.
//   Trashed Spaces count too (spaces.owner_id restricts the user delete).
// - Everything else follows by cascade from auth.users: profile, own photos
//   and videos everywhere, memberships, requests, Co-Admin roles, push
//   tokens, history, unread markers. Their files are removed by the
//   delete triggers of migrations/0062.
// Who is affected hears about it: the new Admin of a handed-over Space,
// everyone who saw a Space that is now gone, and its Frames (woken, so
// they drop back to the pairing screen).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

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
  const name = (await fetchProfilesByUserId(supabaseAdmin, [userId])).get(userId)?.display_name ?? "Jemand";

  const { data: ownedSpaces } = await supabaseAdmin.from("spaces").select("id, name").eq("owner_id", userId);
  const handovers: { spaceName: string; successorId: string; spaceId: string }[] = [];
  const goneAudience = new Map<string, string[]>(); // space name -> people who saw it
  const frameTokens: string[] = [];

  for (const space of ownedSpaces ?? []) {
    const { data: successor } = await supabaseAdmin
      .from("space_co_owners")
      .select("user_id")
      .eq("space_id", space.id)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (successor) {
      handovers.push({ spaceName: space.name as string, successorId: successor.user_id as string, spaceId: space.id as string });
      continue;
    }
    // Nobody to take over: the Space goes, with everything in it.
    const { data: channels } = await supabaseAdmin.from("channels").select("id").eq("space_id", space.id);
    const audience = new Set<string>();
    for (const c of channels ?? []) {
      const { data } = await supabaseAdmin.rpc("sync_channel_audience", { check_channel_id: c.id });
      for (const u of (data ?? []) as string[]) if (u !== userId) audience.add(u);
    }
    goneAudience.set(space.name as string, [...audience]);
    const { data: frames } = await supabaseAdmin.from("frames").select("fcm_token").eq("space_id", space.id);
    for (const f of frames ?? []) if (f.fcm_token) frameTokens.push(f.fcm_token as string);
    const { error } = await supabaseAdmin.from("spaces").delete().eq("id", space.id);
    if (error) return jsonResponse({ error: "space_delete_failed", detail: error.message }, 500);
  }

  const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
  if (deleteError) return jsonResponse({ error: "account_delete_failed", detail: deleteError.message }, 500);

  for (const h of handovers) {
    await pushNotificationToUsers(
      supabaseAdmin,
      [h.successorId],
      { title: "Du bist jetzt Admin", body: `${name} hat das Smile-Konto gelöscht. Du bist jetzt Admin des Space „${h.spaceName}“.` },
      { type: "space_ownership_transferred", space_id: h.spaceId, space_name: h.spaceName },
    );
  }
  for (const [spaceName, people] of goneAudience) {
    await pushNotificationToUsers(
      supabaseAdmin,
      people,
      { title: "Space gelöscht", body: `${name} hat das Smile-Konto gelöscht. Den Space „${spaceName}“ mit allen Alben gibt es nicht mehr.` },
      { type: "space_deleted_with_account" },
    );
  }
  for (const token of frameTokens) {
    try {
      await sendDataMessage(token, { type: "sync", table: "frames", op: "delete" });
    } catch {
      // Best-effort: an offline Frame finds out at its next sync.
    }
  }
  return jsonResponse({ status: "deleted", handed_over: handovers.length, spaces_deleted: goneAudience.size });
});
