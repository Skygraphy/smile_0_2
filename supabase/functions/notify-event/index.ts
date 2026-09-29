// Human-facing notifications raised by the DATABASE itself (emit_event(),
// migrations/0046_share_owner_revoke_and_events.sql) -- the visible
// counterpart of sync-fanout's silent sync. Triggers see every write path,
// so an event can't be missed just because the app that caused it was
// closed right afterwards.
//
// Called only by pg_net; deployed with --no-verify-jwt and authenticated by
// the same shared secret as sync-fanout.
//
// Kinds:
// - co_owner_added {space_id, user_id}: a household with shares gained a
//   co-owner, who now also sees every channel shared into it. Tell each of
//   those channels' own side (decision 2026-09-29: a share belongs to the
//   whole household, but its owner must learn who joins).
// - share_ended {channel_id, space_id, actor_id}: tell the side that did
//   NOT end it.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { spaceManagerIds } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";

// deno-lint-ignore no-explicit-any
type Admin = any;

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: { kind: string; payload: Record<string, string | null> };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  try {
    if (body.kind === "co_owner_added") {
      await coOwnerAdded(supabaseAdmin, body.payload.space_id!, body.payload.user_id!);
    } else if (body.kind === "share_ended") {
      await shareEnded(supabaseAdmin, body.payload.channel_id!, body.payload.space_id!, body.payload.actor_id ?? null);
    } else {
      return jsonResponse({ error: "unknown_kind" }, 400);
    }
  } catch (err) {
    return jsonResponse({ error: "failed", detail: String(err) }, 500);
  }
  return jsonResponse({ status: "ok" });
});

async function displayName(supabaseAdmin: Admin, userId: string): Promise<string> {
  const profiles = await fetchProfilesByUserId(supabaseAdmin, [userId]);
  return profiles.get(userId)?.display_name ?? "Jemand";
}

async function coOwnerAdded(supabaseAdmin: Admin, spaceId: string, userId: string) {
  const [{ data: space }, { data: shares }, name] = await Promise.all([
    supabaseAdmin.from("spaces").select("name").eq("id", spaceId).maybeSingle(),
    supabaseAdmin.from("channel_shares").select("channel_id, channels(name, space_id)").eq("space_id", spaceId),
    displayName(supabaseAdmin, userId),
  ]);
  if (!space) return;
  for (const share of shares ?? []) {
    // deno-lint-ignore no-explicit-any
    const channel = share.channels as any;
    if (!channel) continue;
    const recipients = (await spaceManagerIds(supabaseAdmin, channel.space_id)).filter((id) => id !== userId);
    await pushNotificationToUsers(
      supabaseAdmin,
      recipients,
      {
        title: `Neue Person sieht „${channel.name}“`,
        body: `${name} ist jetzt Co-Owner von „${space.name}“ und sieht damit auch „${channel.name}“.`,
      },
      { type: "share_audience_changed", channel_id: share.channel_id as string, channel_name: channel.name as string },
    );
  }
}

async function shareEnded(supabaseAdmin: Admin, channelId: string, viewingSpaceId: string, actorId: string | null) {
  const [{ data: channel }, { data: viewingSpace }] = await Promise.all([
    supabaseAdmin.from("channels").select("name, space_id, spaces(name)").eq("id", channelId).maybeSingle(),
    supabaseAdmin.from("spaces").select("name").eq("id", viewingSpaceId).maybeSingle(),
  ]);
  if (!channel || !viewingSpace) return;
  // deno-lint-ignore no-explicit-any
  const homeSpaceName = (channel.spaces as any)?.name ?? "";
  const homeManagers = await spaceManagerIds(supabaseAdmin, channel.space_id as string);
  const viewingManagers = await spaceManagerIds(supabaseAdmin, viewingSpaceId);
  const endedByHomeSide = actorId !== null && homeManagers.includes(actorId);

  if (endedByHomeSide) {
    await pushNotificationToUsers(
      supabaseAdmin,
      viewingManagers.filter((id) => id !== actorId),
      {
        title: "Freigabe beendet",
        body: `„${homeSpaceName}“ hat die Freigabe von „${channel.name}“ für „${viewingSpace.name}“ beendet.`,
      },
      { type: "share_ended_for_viewer" },
    );
  } else {
    await pushNotificationToUsers(
      supabaseAdmin,
      homeManagers.filter((id) => id !== actorId),
      {
        title: "Freigabe beendet",
        body: `„${viewingSpace.name}“ sieht „${channel.name}“ nicht mehr.`,
      },
      { type: "share_ended_for_owner", channel_id: channelId, channel_name: channel.name as string },
    );
  }
}
