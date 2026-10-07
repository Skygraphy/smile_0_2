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
// - request_decided {table, id, actor_id}: a membership request/invite, a
//   share request/invite or a co-owner invite was accepted or declined --
//   tell the other side (for an invite: everyone who manages the channel's
//   Space, not only its Administrator). Raised by a trigger (0050), so it
//   arrives even if the deciding app was closed right afterwards.
// - trashed / restored {kind: channel|space, id, actor_id}: a Channel or a
//   whole Space went into the 30-day trash (or came back) -- tell everyone
//   who could see it (decision 2026-09-29: nothing vanishes unannounced).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { spaceManagerIds } from "../_shared/space-access.ts";
import { purgeAfter } from "../_shared/trash.ts";

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

  // deno-lint-ignore no-explicit-any
  let body: { kind: string; payload: Record<string, any> };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  try {
    if (body.kind === "co_owner_added") {
      await coOwnerAdded(supabaseAdmin, body.payload.space_id!, body.payload.user_id!);
    } else if (body.kind === "request_decided") {
      await requestDecided(supabaseAdmin, body.payload.table!, body.payload.id!, body.payload.actor_id ?? null);
    } else if (body.kind === "trashed" || body.kind === "restored") {
      await trashChanged(
        supabaseAdmin,
        body.kind,
        body.payload.kind as "channel" | "space",
        body.payload.id!,
        body.payload.actor_id ?? null,
      );
    } else if (body.kind === "share_ended") {
      await shareEnded(supabaseAdmin, body.payload.channel_id!, body.payload.space_id!, body.payload.actor_id ?? null);
    } else if (body.kind === "request_created") {
      await requestCreated(supabaseAdmin, body.payload.table!, body.payload.id!);
    } else if (body.kind === "member_removed") {
      await memberRemoved(supabaseAdmin, body.payload.channel_id!, body.payload.user_id!, body.payload.actor_id ?? null);
    } else if (body.kind === "co_admin_removed") {
      await coAdminRemoved(supabaseAdmin, body.payload.space_id!, body.payload.user_id!, body.payload.actor_id ?? null);
    } else if (body.kind === "frame_changed") {
      await frameChanged(supabaseAdmin, body.payload);
    } else if (body.kind === "frame_album_removed") {
      await frameAlbumRemoved(supabaseAdmin, body.payload.frame_id!, body.payload.channel_id!, body.payload.actor_id ?? null);
    } else if (body.kind === "album_created") {
      await albumCreated(supabaseAdmin, body.payload.channel_id!, body.payload.actor_id ?? null);
    } else if (body.kind === "album_renamed") {
      await albumRenamed(supabaseAdmin, body.payload);
    } else if (body.kind === "space_renamed") {
      await spaceRenamed(supabaseAdmin, body.payload);
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
        body: `${name} ist jetzt Co-Admin von „${space.name}“ und sieht damit auch das Album „${channel.name}“.`,
      },
      { type: "share_audience_changed", channel_id: share.channel_id as string, channel_name: channel.name as string },
    );
  }
}

async function shareEnded(supabaseAdmin: Admin, channelId: string, viewingSpaceId: string, actorId: string | null) {
  const [{ data: channel }, { data: viewingSpace }] = await Promise.all([
    // The explicit FK hint is required: channels reaches spaces both
    // directly and through channel_shares, and a bare spaces(...) embed is
    // ambiguous (PGRST201) -- it failed silently here, so no "share ended"
    // notification was ever sent (found in the 2026-10-01 live test).
    supabaseAdmin.from("channels").select("name, space_id").eq("id", channelId).maybeSingle(),
    supabaseAdmin.from("spaces").select("name").eq("id", viewingSpaceId).maybeSingle(),
  ]);
  if (!channel || !viewingSpace) return;
  const homeManagers = await spaceManagerIds(supabaseAdmin, channel.space_id as string);
  const viewingManagers = await spaceManagerIds(supabaseAdmin, viewingSpaceId);
  const endedByHomeSide = actorId !== null && homeManagers.includes(actorId);
  // Name the PERSON who ended it, not their household (user feedback).
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  const notification = {
    title: "Nicht mehr geteilt",
    body: `${actor} teilt das Album „${channel.name}“ nicht mehr mit „${viewingSpace.name}“.`,
  };

  if (endedByHomeSide) {
    await pushNotificationToUsers(
      supabaseAdmin,
      viewingManagers.filter((id) => id !== actorId),
      notification,
      { type: "share_ended_for_viewer" },
    );
  } else {
    await pushNotificationToUsers(
      supabaseAdmin,
      homeManagers.filter((id) => id !== actorId),
      notification,
      { type: "share_ended_for_owner", channel_id: channelId, channel_name: channel.name as string },
    );
  }
}

/** Everyone who can see this channel -- the same audience the silent sync uses (0041). */
async function channelAudience(supabaseAdmin: Admin, channelId: string): Promise<string[]> {
  const { data } = await supabaseAdmin.rpc("sync_channel_audience", { check_channel_id: channelId });
  return (data ?? []) as string[];
}

function germanDate(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getUTCDate()).padStart(2, "0")}.${String(d.getUTCMonth() + 1).padStart(2, "0")}.${d.getUTCFullYear()}`;
}

async function trashChanged(
  supabaseAdmin: Admin,
  event: "trashed" | "restored",
  kind: "channel" | "space",
  id: string,
  actorId: string | null,
) {
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  let name: string;
  let deletedAt: string | null;
  const recipients = new Set<string>();

  if (kind === "channel") {
    const { data: channel } = await supabaseAdmin.from("channels").select("name, deleted_at").eq("id", id).maybeSingle();
    if (!channel) return;
    name = channel.name as string;
    deletedAt = channel.deleted_at as string | null;
    for (const u of await channelAudience(supabaseAdmin, id)) recipients.add(u);
  } else {
    const { data: space } = await supabaseAdmin.from("spaces").select("name, deleted_at").eq("id", id).maybeSingle();
    if (!space) return;
    name = space.name as string;
    deletedAt = space.deleted_at as string | null;
    for (const u of await spaceManagerIds(supabaseAdmin, id)) recipients.add(u);
    const { data: channels } = await supabaseAdmin.from("channels").select("id").eq("space_id", id);
    for (const c of channels ?? []) {
      for (const u of await channelAudience(supabaseAdmin, c.id as string)) recipients.add(u);
    }
  }
  if (actorId) recipients.delete(actorId);

  const what = kind === "channel" ? `das Album „${name}“` : `den Space „${name}“ mit allen Alben und Frames`;
  const notification = event === "trashed"
    ? {
      title: kind === "channel" ? "Album gelöscht" : "Space gelöscht",
      body: `${actor} hat ${what} gelöscht. Bis ${deletedAt ? germanDate(purgeAfter(deletedAt)) : "in 30 Tagen"} kann das noch rückgängig gemacht werden.`,
    }
    : {
      title: kind === "channel" ? "Album wiederhergestellt" : "Space wiederhergestellt",
      body: `${actor} hat ${what} wiederhergestellt.`,
    };
  await pushNotificationToUsers(supabaseAdmin, [...recipients], notification, { type: `${kind}_${event}` });
}

function verbFor(status: string): string {
  return status === "accepted" ? "angenommen" : "abgelehnt";
}

async function requestDecided(supabaseAdmin: Admin, table: string, id: string, actorId: string | null) {
  if (table === "space_co_owner_invites") {
    const { data: row } = await supabaseAdmin
      .from("space_co_owner_invites").select("space_id, invitee_user_id, status").eq("id", id).maybeSingle();
    if (!row || row.status === "pending") return;
    const { data: space } = await supabaseAdmin.from("spaces").select("name, owner_id").eq("id", row.space_id).maybeSingle();
    if (!space) return;
    const name = await displayName(supabaseAdmin, row.invitee_user_id as string);
    await pushNotificationToUsers(
      supabaseAdmin,
      [space.owner_id as string].filter((u) => u !== actorId),
      { title: "Einladung beantwortet", body: `${name} hat deine Einladung als Co-Admin von „${space.name}“ ${verbFor(row.status)}.` },
      { type: "space_co_owner_invite_decided", space_id: row.space_id as string, space_name: space.name as string, person_name: name },
    );
    return;
  }

  const isShare = table === "channel_share_requests";
  const { data: row } = await supabaseAdmin
    .from(table)
    .select(isShare ? "channel_id, target_user_id, direction, status" : "channel_id, user_id, direction, status")
    .eq("id", id)
    .maybeSingle();
  if (!row || row.status === "pending") return;
  const personId = (isShare ? row.target_user_id : row.user_id) as string;
  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", row.channel_id).maybeSingle();
  if (!channel) return;
  const verb = verbFor(row.status as string);
  const data = { channel_id: row.channel_id as string, channel_name: channel.name as string };

  if (row.direction === "invite") {
    // The invited person decided -- tell everyone who manages the channel.
    const name = await displayName(supabaseAdmin, personId);
    const managers = (await spaceManagerIds(supabaseAdmin, channel.space_id as string)).filter((u) => u !== actorId);
    await pushNotificationToUsers(
      supabaseAdmin,
      managers,
      isShare
        ? { title: "Einladung beantwortet", body: `${name} hat das Album „${channel.name}“ für den eigenen Space ${verb}.` }
        : { title: "Einladung beantwortet", body: `${name} hat die Einladung ins Album „${channel.name}“ ${verb}.` },
      { type: isShare ? "share_invite_decided" : "membership_invite_decided", ...data, person_name: name },
    );
  } else {
    // A manager decided the person's own request -- tell that person.
    await pushNotificationToUsers(
      supabaseAdmin,
      [personId].filter((u) => u !== actorId),
      isShare
        ? { title: "Anfrage beantwortet", body: `Deine Anfrage, das Album „${channel.name}“ mit deinem Space zu sehen, wurde ${verb}.` }
        : { title: "Anfrage beantwortet", body: `Deine Anfrage, Member im Album „${channel.name}“ zu werden, wurde ${verb}.` },
      { type: isShare ? "share_request_decided" : "membership_request_decided", ...data },
    );
  }
}

/** Someone asked to join an album, or to see it with their own Space
 * (migrations/0057) -- everyone who can decide it hears about it. */
async function requestCreated(supabaseAdmin: Admin, table: string, id: string) {
  const isShare = table === "channel_share_requests";
  const { data: row } = await supabaseAdmin
    .from(table)
    .select(isShare ? "channel_id, target_user_id, status" : "channel_id, user_id, status")
    .eq("id", id)
    .maybeSingle();
  if (!row || row.status !== "pending") return;
  const requesterId = (isShare ? row.target_user_id : row.user_id) as string;
  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", row.channel_id).maybeSingle();
  if (!channel) return;
  const name = await displayName(supabaseAdmin, requesterId);
  const managers = (await spaceManagerIds(supabaseAdmin, channel.space_id as string)).filter((u) => u !== requesterId);
  await pushNotificationToUsers(
    supabaseAdmin,
    managers,
    isShare
      ? { title: "Neue Anfrage", body: `${name} möchte das Album „${channel.name}“ mit dem eigenen Space sehen. Antworten unter Neuigkeiten.` }
      : { title: "Neue Anfrage", body: `${name} möchte Member im Album „${channel.name}“ werden. Antworten unter Neuigkeiten.` },
    { type: "request_created", channel_id: row.channel_id as string, channel_name: channel.name as string, person_name: name },
  );
}

/** A person is no longer a member of an album (migrations/0057): left on
 * their own -> the managers hear it; removed by a manager -> they do. */
async function memberRemoved(supabaseAdmin: Admin, channelId: string, userId: string, actorId: string | null) {
  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", channelId).maybeSingle();
  if (!channel) return;
  const data = { channel_id: channelId, channel_name: channel.name as string };
  if (actorId === userId) {
    const name = await displayName(supabaseAdmin, userId);
    const managers = (await spaceManagerIds(supabaseAdmin, channel.space_id as string)).filter((u) => u !== userId);
    await pushNotificationToUsers(
      supabaseAdmin,
      managers,
      { title: "Album verlassen", body: `${name} hat das Album „${channel.name}“ verlassen.` },
      { type: "member_left", ...data, person_name: name },
    );
  } else {
    const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
    await pushNotificationToUsers(
      supabaseAdmin,
      [userId],
      { title: "Nicht mehr im Album", body: `${actor} hat dich aus dem Album „${channel.name}“ entfernt.` },
      { type: "member_removed" },
    );
  }
}

/** A Co-Admin is gone (migrations/0057): stepped down -> the Admin hears
 * it; removed by the Admin -> that person does. A handover makes the
 * Co-Admin the new Admin, which also deletes their Co-Admin row -- that is
 * not a removal, "Du bist jetzt Admin" already tells them. */
async function coAdminRemoved(supabaseAdmin: Admin, spaceId: string, userId: string, actorId: string | null) {
  const { data: space } = await supabaseAdmin.from("spaces").select("name, owner_id").eq("id", spaceId).maybeSingle();
  if (!space || space.owner_id === userId) return;
  const data = { space_id: spaceId, space_name: space.name as string };
  if (actorId === userId) {
    const name = await displayName(supabaseAdmin, userId);
    await pushNotificationToUsers(
      supabaseAdmin,
      [space.owner_id as string],
      { title: "Co-Admin-Rolle abgegeben", body: `${name} verwaltet den Space „${space.name}“ nicht mehr mit.` },
      { type: "co_admin_stepped_down", ...data, person_name: name },
    );
  } else {
    const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
    await pushNotificationToUsers(
      supabaseAdmin,
      [userId],
      { title: "Nicht mehr Co-Admin", body: `${actor} hat dich als Co-Admin von „${space.name}“ entfernt.` },
      { type: "co_admin_removed" },
    );
  }
}

// --- migrations/0064: the remaining silent changes ---------------------------

/** A Frame was renamed, paired, revoked/reactivated or had a setting
 * changed -> the Space's Admin and Co-Admins, except whoever did it. */
// deno-lint-ignore no-explicit-any
async function frameChanged(supabaseAdmin: Admin, p: Record<string, any>) {
  const { data: frame } = await supabaseAdmin.from("frames").select("space_id, spaces(name)").eq("id", p.frame_id).maybeSingle();
  if (!frame) return;
  // deno-lint-ignore no-explicit-any
  const spaceName = (frame.spaces as any)?.name ?? "";
  const actorId = (p.actor_id ?? null) as string | null;
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : null;
  const recipients = (await spaceManagerIds(supabaseAdmin, frame.space_id as string)).filter((u) => u !== actorId);
  const data = { type: "frame_changed", space_id: frame.space_id as string, space_name: spaceName, frame_name: p.new_name as string };

  const messages: { title: string; body: string }[] = [];
  if (p.old_state === "pending" && p.new_state === "active") {
    messages.push({ title: "Frame verbunden", body: `Der Frame „${p.new_name}“ in „${spaceName}“ ist jetzt verbunden und zeigt Fotos.` });
  } else if (p.old_state !== p.new_state && p.new_state === "revoked") {
    messages.push({ title: "Frame widerrufen", body: `${actor ?? "Jemand"} hat den Frame „${p.new_name}“ in „${spaceName}“ widerrufen.` });
  } else if (p.old_state === "revoked" && p.new_state === "active") {
    messages.push({ title: "Frame wieder aktiv", body: `${actor ?? "Jemand"} hat den Frame „${p.new_name}“ in „${spaceName}“ wieder aktiviert.` });
  }
  if (p.old_name !== p.new_name) {
    messages.push({ title: "Frame umbenannt", body: `${actor ?? "Jemand"} hat den Frame „${p.old_name}“ in „${p.new_name}“ umbenannt.` });
  }
  if (p.video_sound !== null && p.video_sound !== undefined) {
    messages.push({
      title: "Frame-Einstellung geändert",
      body: `${actor ?? "Jemand"}: Am Frame „${p.new_name}“ laufen Videos jetzt ${p.video_sound ? "mit" : "ohne"} Ton.`,
    });
  }
  if (p.channel_switch !== null && p.channel_switch !== undefined) {
    messages.push({
      title: "Frame-Einstellung geändert",
      body: `${actor ?? "Jemand"}: Am Frame „${p.new_name}“ ist der Album-Wechsel jetzt ${p.channel_switch ? "erlaubt" : "aus"}.`,
    });
  }
  for (const m of messages) await pushNotificationToUsers(supabaseAdmin, recipients, m, data);
}

async function frameAlbumRemoved(supabaseAdmin: Admin, frameId: string, channelId: string, actorId: string | null) {
  const [{ data: frame }, { data: channel }] = await Promise.all([
    supabaseAdmin.from("frames").select("name, space_id, spaces(name)").eq("id", frameId).maybeSingle(),
    supabaseAdmin.from("channels").select("name").eq("id", channelId).maybeSingle(),
  ]);
  if (!frame || !channel) return;
  // deno-lint-ignore no-explicit-any
  const spaceName = (frame.spaces as any)?.name ?? "";
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  const recipients = (await spaceManagerIds(supabaseAdmin, frame.space_id as string)).filter((u) => u !== actorId);
  await pushNotificationToUsers(
    supabaseAdmin,
    recipients,
    { title: "Frame zeigt Album nicht mehr", body: `${actor}: Der Frame „${frame.name}“ zeigt „${channel.name}“ nicht mehr.` },
    { type: "frame_changed", space_id: frame.space_id as string, space_name: spaceName, frame_name: frame.name as string },
  );
}

async function albumCreated(supabaseAdmin: Admin, channelId: string, actorId: string | null) {
  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", channelId).maybeSingle();
  if (!channel) return;
  const { data: space } = await supabaseAdmin.from("spaces").select("name").eq("id", channel.space_id).maybeSingle();
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  const recipients = (await spaceManagerIds(supabaseAdmin, channel.space_id as string)).filter((u) => u !== actorId);
  await pushNotificationToUsers(
    supabaseAdmin,
    recipients,
    { title: "Neues Album", body: `${actor} hat das Album „${channel.name}“ in „${space?.name ?? ""}“ angelegt.` },
    { type: "album_created", channel_id: channelId, channel_name: channel.name as string },
  );
}

// deno-lint-ignore no-explicit-any
async function albumRenamed(supabaseAdmin: Admin, p: Record<string, any>) {
  const actorId = (p.actor_id ?? null) as string | null;
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  const recipients = (await channelAudience(supabaseAdmin, p.channel_id)).filter((u) => u !== actorId);
  await pushNotificationToUsers(
    supabaseAdmin,
    recipients,
    { title: "Album umbenannt", body: `${actor} hat das Album „${p.old_name}“ in „${p.new_name}“ umbenannt.` },
    { type: "album_renamed", channel_id: p.channel_id, channel_name: p.new_name },
  );
}

/** Everyone who sees the Space or any of its albums hears about it. */
// deno-lint-ignore no-explicit-any
async function spaceRenamed(supabaseAdmin: Admin, p: Record<string, any>) {
  const actorId = (p.actor_id ?? null) as string | null;
  const actor = actorId ? await displayName(supabaseAdmin, actorId) : "Jemand";
  const people = new Set(await spaceManagerIds(supabaseAdmin, p.space_id));
  const { data: channels } = await supabaseAdmin.from("channels").select("id").eq("space_id", p.space_id).is("deleted_at", null);
  for (const c of channels ?? []) for (const u of await channelAudience(supabaseAdmin, c.id as string)) people.add(u);
  if (actorId) people.delete(actorId);
  await pushNotificationToUsers(
    supabaseAdmin,
    [...people],
    { title: "Space umbenannt", body: `${actor} hat den Space „${p.old_name}“ in „${p.new_name}“ umbenannt.` },
    { type: "space_renamed", space_id: p.space_id, space_name: p.new_name },
  );
}
