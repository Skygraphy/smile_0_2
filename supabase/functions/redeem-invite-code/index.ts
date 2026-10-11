// Redeems an invite code (migrations/0073, decided 2026-10-11). It maps
// onto the existing request tables, so accepting, events and pushes work
// as they always have:
//   via "qr"    (scanned in person) -> an invite, accepted at once
//   via "typed" (from a message)    -> a request the album's admins decide
// A Co-Admin code works by QR only.
//
// Answers { status }:
//   joined          -- in the album / Co-Admin now
//   requested       -- the admins still decide (Neuigkeiten)
//   needs_space     -- album_share: pick one of `spaces`, call again with space_id
//   already_member / already_shared / already_co_owner
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  code: string;
  via: "qr" | "typed";
  space_id?: string;
}

// deno-lint-ignore no-explicit-any
type Admin = any;

const now = () => new Date().toISOString();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  // "K7P-2QX", "k7p 2qx", or the QR's "smile:invite:K7P2QX".
  const code = (body.code ?? "").toUpperCase().replace(/^SMILE:INVITE:/, "").replace(/[^A-Z0-9]/g, "");
  if (code.length !== 6 || (body.via !== "qr" && body.via !== "typed")) return jsonResponse({ error: "invalid_code" }, 400);

  const admin: Admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: invite } = await admin.from("invite_codes").select("*").eq("code", code).maybeSingle();
  if (!invite || invite.revoked_at) return jsonResponse({ error: "invalid_code" }, 404);
  if (new Date(invite.expires_at) < new Date()) return jsonResponse({ error: "expired_code" }, 410);

  if (invite.kind === "space_co_owner") return await coOwner(admin, invite.target_id, userId, body.via);
  const { data: channel } = await admin
    .from("channels")
    .select("id, name, space_id, deleted_at")
    .eq("id", invite.target_id)
    .maybeSingle();
  if (!channel || channel.deleted_at) return jsonResponse({ error: "invalid_code" }, 404);
  if (invite.kind === "album_member") return await albumMember(admin, channel, userId, body.via);
  return await albumShare(admin, channel, userId, body.via, body.space_id);
});

// deno-lint-ignore no-explicit-any
async function albumMember(admin: Admin, channel: any, userId: string, via: string): Promise<Response> {
  const result = { kind: "album_member", channel_id: channel.id, channel_name: channel.name };
  const { data: member } = await admin
    .from("channel_members")
    .select("user_id")
    .eq("channel_id", channel.id)
    .eq("user_id", userId)
    .maybeSingle();
  if (member) return jsonResponse({ status: "already_member", ...result });

  const { data: pending } = await admin
    .from("channel_membership_requests")
    .select("id, direction")
    .eq("channel_id", channel.id)
    .eq("user_id", userId)
    .eq("status", "pending")
    .maybeSingle();

  // Already invited (e.g. by name): the code counts as saying yes.
  if (via === "qr" || pending?.direction === "invite") {
    let id = pending?.id;
    if (!id) {
      const { data: created, error } = await admin
        .from("channel_membership_requests")
        .insert({ channel_id: channel.id, user_id: userId, direction: "invite" })
        .select("id")
        .single();
      if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
      id = created.id;
    }
    const { error } = await admin
      .from("channel_membership_requests")
      .update({ status: "accepted", decided_at: now() })
      .eq("id", id);
    if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
    return jsonResponse({ status: "joined", ...result });
  }

  if (!pending) {
    const { error } = await admin
      .from("channel_membership_requests")
      .insert({ channel_id: channel.id, user_id: userId, direction: "request" });
    if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
  }
  return jsonResponse({ status: "requested", ...result });
}

async function albumShare(
  admin: Admin,
  // deno-lint-ignore no-explicit-any
  channel: any,
  userId: string,
  via: string,
  spaceId: string | undefined,
): Promise<Response> {
  const result = { kind: "album_share", channel_id: channel.id, channel_name: channel.name };
  // The Spaces this person manages -- except the album's own.
  const [{ data: owned }, { data: coOwned }] = await Promise.all([
    admin.from("spaces").select("id, name").eq("owner_id", userId).is("deleted_at", null),
    admin.from("space_co_owners").select("spaces!inner(id, name, deleted_at)").eq("user_id", userId),
  ]);
  const spaces = new Map<string, string>();
  for (const s of owned ?? []) spaces.set(s.id, s.name);
  // deno-lint-ignore no-explicit-any
  for (const row of (coOwned ?? []) as any[]) {
    if (!row.spaces.deleted_at) spaces.set(row.spaces.id, row.spaces.name);
  }
  spaces.delete(channel.space_id);
  if (spaces.size === 0) return jsonResponse({ error: "no_space" }, 409);

  let chosen = spaceId;
  if (chosen && !spaces.has(chosen)) return jsonResponse({ error: "not_your_space" }, 403);
  if (!chosen) {
    if (spaces.size > 1) {
      return jsonResponse({
        status: "needs_space",
        ...result,
        spaces: [...spaces].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name)),
      });
    }
    chosen = [...spaces.keys()][0];
  }
  const spaceResult = { ...result, space_id: chosen, space_name: spaces.get(chosen) };

  const { data: shared } = await admin
    .from("channel_shares")
    .select("space_id")
    .eq("channel_id", channel.id)
    .eq("space_id", chosen)
    .maybeSingle();
  if (shared) return jsonResponse({ status: "already_shared", ...spaceResult });

  if (via === "qr") {
    const { data: pending } = await admin
      .from("channel_share_requests")
      .select("id")
      .eq("channel_id", channel.id)
      .eq("target_user_id", userId)
      .eq("direction", "invite")
      .eq("status", "pending")
      .maybeSingle();
    let id = pending?.id;
    if (!id) {
      const { data: created, error } = await admin
        .from("channel_share_requests")
        .insert({ channel_id: channel.id, target_user_id: userId, direction: "invite", space_id: chosen })
        .select("id")
        .single();
      if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
      id = created.id;
    }
    const { error } = await admin
      .from("channel_share_requests")
      .update({ status: "accepted", space_id: chosen, decided_at: now() })
      .eq("id", id);
    if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
    return jsonResponse({ status: "joined", ...spaceResult });
  }

  const { data: pendingRequest } = await admin
    .from("channel_share_requests")
    .select("id")
    .eq("channel_id", channel.id)
    .eq("space_id", chosen)
    .eq("direction", "request")
    .eq("status", "pending")
    .maybeSingle();
  if (!pendingRequest) {
    const { error } = await admin
      .from("channel_share_requests")
      .insert({ channel_id: channel.id, target_user_id: userId, direction: "request", space_id: chosen });
    if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
  }
  return jsonResponse({ status: "requested", ...spaceResult });
}

async function coOwner(admin: Admin, spaceId: string, userId: string, via: string): Promise<Response> {
  // Becoming Co-Admin only in person -- a forwarded message is never enough.
  if (via !== "qr") return jsonResponse({ error: "qr_only" }, 403);
  const { data: space } = await admin.from("spaces").select("id, name, owner_id, deleted_at").eq("id", spaceId).maybeSingle();
  if (!space || space.deleted_at) return jsonResponse({ error: "invalid_code" }, 404);
  const result = { kind: "space_co_owner", space_id: space.id, space_name: space.name };
  const { data: already } = await admin
    .from("space_co_owners")
    .select("user_id")
    .eq("space_id", space.id)
    .eq("user_id", userId)
    .maybeSingle();
  if (already || space.owner_id === userId) return jsonResponse({ status: "already_co_owner", ...result });

  const { data: pending } = await admin
    .from("space_co_owner_invites")
    .select("id")
    .eq("space_id", space.id)
    .eq("invitee_user_id", userId)
    .eq("status", "pending")
    .maybeSingle();
  let id = pending?.id;
  if (!id) {
    const { data: created, error } = await admin
      .from("space_co_owner_invites")
      .insert({ space_id: space.id, invitee_user_id: userId })
      .select("id")
      .single();
    if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
    id = created.id;
  }
  const { error } = await admin
    .from("space_co_owner_invites")
    .update({ status: "accepted", decided_at: now() })
    .eq("id", id);
  if (error) return jsonResponse({ error: "redeem_failed", detail: error.message }, 500);
  return jsonResponse({ status: "joined", ...result });
}
