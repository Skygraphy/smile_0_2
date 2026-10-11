// An invite code for an album or a Space (migrations/0073, decided
// 2026-10-11): shown as a QR code to someone standing next to you, or sent
// as text. One active code per (kind, target, creator); asking again
// returns it, `renew` replaces it (the old one stops working at once).
//
// Who may: album_member / album_share -- the album's Administrator or a
// Co-Admin of its Space; space_co_owner -- the Space's Administrator only
// (same rule as invite-space-co-owner).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const KINDS = ["album_member", "album_share", "space_co_owner"] as const;
type Kind = (typeof KINDS)[number];
// No look-alikes: no 0/O, 1/I/L.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

interface RequestBody {
  kind: Kind;
  target_id: string;
  renew?: boolean;
}

function newCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

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
  if (!KINDS.includes(body.kind) || !body.target_id) return jsonResponse({ error: "kind_and_target_required" }, 400);

  const admin = createClient(supabaseUrl, serviceRoleKey);

  let targetName: string;
  if (body.kind === "space_co_owner") {
    const { data: space } = await admin.from("spaces").select("id, name, deleted_at").eq("id", body.target_id).maybeSingle();
    if (!space || space.deleted_at) return jsonResponse({ error: "space_not_found" }, 404);
    const access = await resolveSpaceAccess(admin, space.id, userId);
    if (!access.isAdmin && !access.isStaff) return jsonResponse({ error: "not_space_admin" }, 403);
    targetName = space.name;
  } else {
    const { data: channel } = await admin
      .from("channels")
      .select("id, name, space_id, deleted_at")
      .eq("id", body.target_id)
      .maybeSingle();
    if (!channel || channel.deleted_at) return jsonResponse({ error: "channel_not_found" }, 404);
    const access = await resolveSpaceAccess(admin, channel.space_id, userId);
    if (!access.manages && !access.isStaff) return jsonResponse({ error: "not_channel_sco" }, 403);
    targetName = channel.name;
  }

  const active = () =>
    admin
      .from("invite_codes")
      .select("id, code, expires_at")
      .eq("kind", body.kind)
      .eq("target_id", body.target_id)
      .eq("created_by", userId)
      .is("revoked_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false });

  if (!body.renew) {
    const { data: existing } = await active().limit(1).maybeSingle();
    if (existing) return jsonResponse({ code: existing.code, expires_at: existing.expires_at, target_name: targetName });
  } else {
    await admin
      .from("invite_codes")
      .update({ revoked_at: new Date().toISOString() })
      .eq("kind", body.kind)
      .eq("target_id", body.target_id)
      .eq("created_by", userId)
      .is("revoked_at", null);
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const { data: created, error } = await admin
      .from("invite_codes")
      .insert({ code: newCode(), kind: body.kind, target_id: body.target_id, created_by: userId })
      .select("code, expires_at")
      .single();
    if (!error && created) return jsonResponse({ code: created.code, expires_at: created.expires_at, target_name: targetName });
    if (!error?.message.includes("invite_codes_code_key")) {
      return jsonResponse({ error: "create_failed", detail: error?.message }, 500);
    }
  }
  return jsonResponse({ error: "create_failed" }, 500);
});
