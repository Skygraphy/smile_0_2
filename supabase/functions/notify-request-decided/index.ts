// Called by the client immediately after it successfully decides a pending
// request/invite (channel membership, channel share, or Space co-owner) --
// deciding itself stays a plain RLS-governed table update (see
// membership_service.dart's/space_service.dart's own doc comments on why),
// this is purely the "let the other side know" side effect layered on top,
// fire-and-forget from the client's point of view. Resolving *who* "the
// other side" is mirrors list-my-invites/index.ts's own counterpart logic:
// for an 'invite', the decider is the invitee, so the other side is the
// channel's/Space's founder; for a 'request', the decider is the founder,
// so the other side is the original requester.
//
// Best-effort and never surfaces an error to the client: this runs after
// the real state change already succeeded, so a failure here should never
// look like the decide action itself failed.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type Kind = "membership" | "share" | "co_owner";

interface RequestBody {
  kind: Kind;
  id: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.kind || !body.id) return jsonResponse({ error: "kind_and_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  try {
    if (body.kind === "membership") {
      await notifyMembershipDecided(supabaseAdmin, body.id);
    } else if (body.kind === "share") {
      await notifyShareDecided(supabaseAdmin, body.id);
    } else if (body.kind === "co_owner") {
      await notifyCoOwnerInviteDecided(supabaseAdmin, body.id);
    }
  } catch {
    // Best-effort -- see header comment.
  }

  return jsonResponse({ status: "ok" });
});

function verbFor(status: string): string {
  return status === "accepted" ? "angenommen" : "abgelehnt";
}

// deno-lint-ignore no-explicit-any
async function decidedByName(supabaseAdmin: any, userId: string): Promise<string> {
  const profiles = await fetchProfilesByUserId(supabaseAdmin, [userId]);
  return profiles.get(userId)?.display_name ?? "Jemand";
}

// deno-lint-ignore no-explicit-any
async function notifyMembershipDecided(supabaseAdmin: any, id: string) {
  const { data: row } = await supabaseAdmin
    .from("channel_membership_requests")
    .select("channel_id, user_id, direction, status")
    .eq("id", id)
    .maybeSingle();
  if (!row || row.status === "pending") return;

  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", row.channel_id).maybeSingle();
  if (!channel) return;
  const verb = verbFor(row.status as string);

  if (row.direction === "invite") {
    // The invitee (row.user_id) decided -- notify the channel's founder.
    const { data: space } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle();
    if (!space) return;
    const name = await decidedByName(supabaseAdmin, row.user_id as string);
    await pushNotificationToUsers(
      supabaseAdmin,
      [space.owner_id as string],
      { title: "Einladung beantwortet", body: `${name} hat deine Einladung zu "${channel.name}" ${verb}.` },
      { type: "membership_invite_decided", channel_id: row.channel_id as string, channel_name: channel.name as string },
    );
  } else {
    // The founder decided a self-initiated request -- notify the requester.
    await pushNotificationToUsers(
      supabaseAdmin,
      [row.user_id as string],
      { title: "Beitrittsanfrage beantwortet", body: `Deine Anfrage für "${channel.name}" wurde ${verb}.` },
      { type: "membership_request_decided", channel_id: row.channel_id as string, channel_name: channel.name as string },
    );
  }
}

// deno-lint-ignore no-explicit-any
async function notifyShareDecided(supabaseAdmin: any, id: string) {
  const { data: row } = await supabaseAdmin
    .from("channel_share_requests")
    .select("channel_id, target_user_id, direction, status")
    .eq("id", id)
    .maybeSingle();
  if (!row || row.status === "pending") return;

  const { data: channel } = await supabaseAdmin.from("channels").select("name, space_id").eq("id", row.channel_id).maybeSingle();
  if (!channel) return;
  const verb = verbFor(row.status as string);

  if (row.direction === "invite") {
    const { data: space } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle();
    if (!space) return;
    const name = await decidedByName(supabaseAdmin, row.target_user_id as string);
    await pushNotificationToUsers(
      supabaseAdmin,
      [space.owner_id as string],
      { title: "Freigabe-Einladung beantwortet", body: `${name} hat deine Freigabe-Einladung für "${channel.name}" ${verb}.` },
      { type: "share_invite_decided", channel_id: row.channel_id as string, channel_name: channel.name as string },
    );
  } else {
    await pushNotificationToUsers(
      supabaseAdmin,
      [row.target_user_id as string],
      { title: "Freigabe-Anfrage beantwortet", body: `Deine Freigabe-Anfrage für "${channel.name}" wurde ${verb}.` },
      { type: "share_request_decided", channel_id: row.channel_id as string, channel_name: channel.name as string },
    );
  }
}

// deno-lint-ignore no-explicit-any
async function notifyCoOwnerInviteDecided(supabaseAdmin: any, id: string) {
  const { data: row } = await supabaseAdmin
    .from("space_co_owner_invites")
    .select("space_id, invitee_user_id, status")
    .eq("id", id)
    .maybeSingle();
  if (!row || row.status === "pending") return;

  const { data: space } = await supabaseAdmin.from("spaces").select("name, owner_id").eq("id", row.space_id).maybeSingle();
  if (!space) return;
  const verb = verbFor(row.status as string);
  const name = await decidedByName(supabaseAdmin, row.invitee_user_id as string);

  await pushNotificationToUsers(
    supabaseAdmin,
    [space.owner_id as string],
    { title: "Einladung beantwortet", body: `${name} hat deine Einladung zur Verwaltung von "${space.name}" ${verb}.` },
    { type: "space_co_owner_invite_decided", space_id: row.space_id as string, space_name: space.name as string },
  );
}
