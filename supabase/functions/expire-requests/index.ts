// Unanswered invites and requests expire after 30 days (decision
// 2026-10-06, migrations/0062: daily cron -> outbox -> here). The side
// that was waiting is told, then the row is deleted -- an open invite
// that nobody will ever answer is exactly the kind of leftover the user
// does not want.
//
// Called only by the database; authenticated by the shared secret.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { spaceManagerIds } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";

export const EXPIRE_DAYS = 30;

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const cutoff = new Date(Date.now() - EXPIRE_DAYS * 24 * 3600 * 1000).toISOString();

  const [{ data: memberships }, { data: shares }, { data: coAdmins }] = await Promise.all([
    supabaseAdmin.from("channel_membership_requests").select("id, channel_id, user_id, direction")
      .eq("status", "pending").lt("requested_at", cutoff),
    supabaseAdmin.from("channel_share_requests").select("id, channel_id, target_user_id, direction")
      .eq("status", "pending").lt("requested_at", cutoff),
    supabaseAdmin.from("space_co_owner_invites").select("id, space_id, invitee_user_id")
      .eq("status", "pending").lt("requested_at", cutoff),
  ]);

  const channelIds = [...new Set([...(memberships ?? []), ...(shares ?? [])].map((r) => r.channel_id as string))];
  const spaceIds = [...new Set((coAdmins ?? []).map((r) => r.space_id as string))];
  const [{ data: channels }, { data: spaces }] = await Promise.all([
    channelIds.length ? supabaseAdmin.from("channels").select("id, name, space_id").in("id", channelIds) : { data: [] },
    spaceIds.length ? supabaseAdmin.from("spaces").select("id, name, owner_id").in("id", spaceIds) : { data: [] },
  ]);
  // deno-lint-ignore no-explicit-any
  const channelById = new Map((channels ?? []).map((c: any) => [c.id as string, c]));
  // deno-lint-ignore no-explicit-any
  const spaceById = new Map((spaces ?? []).map((s: any) => [s.id as string, s]));
  const people = await fetchProfilesByUserId(supabaseAdmin, [
    ...(memberships ?? []).map((r) => r.user_id as string),
    ...(shares ?? []).map((r) => r.target_user_id as string),
    ...(coAdmins ?? []).map((r) => r.invitee_user_id as string),
  ]);
  const nameOf = (id: string) => people.get(id)?.display_name ?? "Jemand";

  let expired = 0;
  for (const r of memberships ?? []) {
    const channel = channelById.get(r.channel_id as string);
    if (channel) {
      if (r.direction === "invite") {
        await pushNotificationToUsers(
          supabaseAdmin,
          await spaceManagerIds(supabaseAdmin, channel.space_id as string),
          { title: "Einladung abgelaufen", body: `${nameOf(r.user_id as string)} hat die Einladung ins Album „${channel.name}“ nicht beantwortet.` },
          { type: "request_expired", channel_id: r.channel_id as string, channel_name: channel.name as string },
        );
      } else {
        await pushNotificationToUsers(
          supabaseAdmin,
          [r.user_id as string],
          { title: "Anfrage abgelaufen", body: `Deine Anfrage, Member im Album „${channel.name}“ zu werden, wurde nicht beantwortet.` },
          { type: "own_request_expired" },
        );
      }
    }
    await supabaseAdmin.from("channel_membership_requests").delete().eq("id", r.id);
    expired++;
  }
  for (const r of shares ?? []) {
    const channel = channelById.get(r.channel_id as string);
    if (channel) {
      if (r.direction === "invite") {
        await pushNotificationToUsers(
          supabaseAdmin,
          await spaceManagerIds(supabaseAdmin, channel.space_id as string),
          { title: "Einladung abgelaufen", body: `${nameOf(r.target_user_id as string)} hat das Teilen von „${channel.name}“ nicht beantwortet.` },
          { type: "request_expired", channel_id: r.channel_id as string, channel_name: channel.name as string },
        );
      } else {
        await pushNotificationToUsers(
          supabaseAdmin,
          [r.target_user_id as string],
          { title: "Anfrage abgelaufen", body: `Deine Anfrage, das Album „${channel.name}“ mit deinem Space zu sehen, wurde nicht beantwortet.` },
          { type: "own_request_expired" },
        );
      }
    }
    await supabaseAdmin.from("channel_share_requests").delete().eq("id", r.id);
    expired++;
  }
  for (const r of coAdmins ?? []) {
    const space = spaceById.get(r.space_id as string);
    if (space) {
      await pushNotificationToUsers(
        supabaseAdmin,
        [space.owner_id as string],
        { title: "Einladung abgelaufen", body: `${nameOf(r.invitee_user_id as string)} hat die Einladung als Co-Admin von „${space.name}“ nicht beantwortet.` },
        { type: "co_admin_invite_expired", space_id: r.space_id as string, space_name: space.name as string },
      );
    }
    await supabaseAdmin.from("space_co_owner_invites").delete().eq("id", r.id);
    expired++;
  }
  return jsonResponse({ status: "ok", expired });
});
