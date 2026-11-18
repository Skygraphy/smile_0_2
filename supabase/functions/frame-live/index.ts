// "Was sieht Oma gerade?" (2026-11-18, migrations/0107): the Space's Admin
// or a Co-Admin looks at a Frame's screen live -- for checking, not for
// watching over anyone. The Frame always shows who is looking, nothing is
// kept (one picture, overwritten, deleted at the end), a look ends by
// itself after 5 minutes.
//
// App (user session):   {action: "start" | "get" | "stop", frame_id}
// Frame (device token): {action: "upload", access_token, image (base64 PNG), state}
//
// "get" every few seconds keeps it going (until = now + 20 s, at most
// started_at + 5 min) and returns the latest picture as a short-lived URL.
// The Frame sends while until lies ahead; the answer tells it to stop.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";
import { verifyFrameAccessToken } from "../_shared/frame-jwt.ts";
import { isSpaceOwnerOrCoOwner } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const admin = createClient(supabaseUrl, serviceRoleKey);

const BUCKET = "frame-live";
const KEEP_MS = 20 * 1000;
const MAX_MS = 5 * 60 * 1000;
const REPUSH_MS = 10 * 1000;
const MAX_IMAGE_BYTES = 1_500_000;

const path = (frameId: string) => `${frameId}.png`;

async function displayName(userId: string): Promise<string> {
  const { data } = await admin.from("profiles").select("display_name").eq("user_id", userId).maybeSingle();
  return (data?.display_name as string | undefined)?.trim() || "";
}

async function wakeFrame(frameId: string, fcmToken: string | null, watcherName: string) {
  await admin.from("frame_live").update({ pushed_at: new Date().toISOString() }).eq("frame_id", frameId);
  if (!fcmToken) return;
  try {
    await sendDataMessage(fcmToken, { type: "live", watcher: watcherName });
  } catch (e) {
    console.error(`frame-live: push failed ${e}`);
  }
}

async function endLook(frameId: string) {
  await admin.from("frame_live").delete().eq("frame_id", frameId);
  await admin.storage.from(BUCKET).remove([path(frameId)]);
}

async function fromFrame(body: { access_token?: string; image?: string; state?: unknown }) {
  if (!body.access_token) return jsonResponse({ error: "access_token_required" }, 400);
  let claims;
  try {
    claims = await verifyFrameAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }
  const { data: credentials } = await admin.from("frame_credentials").select("refresh_secret_version")
    .eq("frame_id", claims.frame_id).maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

  const { data: live } = await admin.from("frame_live").select("watcher_id, until").eq("frame_id", claims.frame_id).maybeSingle();
  if (!live || new Date(live.until as string) <= new Date()) {
    if (live) await endLook(claims.frame_id);
    return jsonResponse({ go_on: false });
  }
  if (body.image) {
    const bytes = decodeBase64(body.image);
    if (bytes.length > MAX_IMAGE_BYTES) return jsonResponse({ error: "image_too_large" }, 413);
    const { error } = await admin.storage.from(BUCKET).upload(path(claims.frame_id), bytes, { contentType: "image/png", upsert: true });
    if (error) return jsonResponse({ error: "upload_failed" }, 500);
  }
  await admin.from("frame_live").update({
    captured_at: new Date().toISOString(),
    state: body.state && typeof body.state === "object" ? body.state : null,
  }).eq("frame_id", claims.frame_id);
  return jsonResponse({ go_on: true, watcher: await displayName(live.watcher_id as string) });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: { action?: string; frame_id?: string; access_token?: string; image?: string; state?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (body.action === "upload") return await fromFrame(body);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const asUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const me = userData.user.id;
  if (!body.frame_id) return jsonResponse({ error: "frame_id_required" }, 400);

  const { data: frame } = await admin.from("frames").select("id, space_id, fcm_token, last_seen_at, lifecycle_state")
    .eq("id", body.frame_id).maybeSingle();
  if (!frame || frame.lifecycle_state !== "active") return jsonResponse({ error: "frame_not_found" }, 404);
  // Only the Space's Admin and Co-Admins (Ernst 2026-11-18).
  if (!(await isSpaceOwnerOrCoOwner(admin, frame.space_id as string, me))) return jsonResponse({ error: "forbidden" }, 403);

  const now = Date.now();
  const { data: live } = await admin.from("frame_live").select("*").eq("frame_id", frame.id).maybeSingle();

  if (body.action === "stop") {
    if (live && live.watcher_id === me) await endLook(frame.id as string);
    return jsonResponse({ ok: true });
  }

  if (body.action === "start") {
    // Someone else is looking right now: one at a time, the Frame names one person.
    if (live && live.watcher_id !== me && new Date(live.until as string).getTime() > now) {
      return jsonResponse({ error: "busy", watcher: await displayName(live.watcher_id as string) });
    }
    await admin.storage.from(BUCKET).remove([path(frame.id as string)]);
    await admin.from("frame_live").upsert({
      frame_id: frame.id, watcher_id: me, started_at: new Date(now).toISOString(),
      until: new Date(now + KEEP_MS).toISOString(), pushed_at: null, captured_at: null, state: null,
    });
    await wakeFrame(frame.id as string, frame.fcm_token as string | null, await displayName(me));
    return jsonResponse({ ok: true, ends_at: new Date(now + MAX_MS).toISOString() });
  }

  if (body.action === "get") {
    if (!live || live.watcher_id !== me) return jsonResponse({ ended: true });
    const endsAt = new Date(live.started_at as string).getTime() + MAX_MS;
    if (now >= endsAt) {
      await endLook(frame.id as string);
      return jsonResponse({ ended: true });
    }
    await admin.from("frame_live").update({ until: new Date(Math.min(now + KEEP_MS, endsAt)).toISOString() }).eq("frame_id", frame.id);
    const captured = live.captured_at ? new Date(live.captured_at as string).getTime() : 0;
    // Pictures stopped (push lost, Frame was busy): wake it once more.
    if (now - captured > REPUSH_MS && now - (live.pushed_at ? new Date(live.pushed_at as string).getTime() : 0) > REPUSH_MS) {
      await wakeFrame(frame.id as string, frame.fcm_token as string | null, await displayName(me));
    }
    let url: string | null = null;
    if (live.captured_at) {
      const { data } = await admin.storage.from(BUCKET).createSignedUrl(path(frame.id as string), 60);
      url = data?.signedUrl ?? null;
    }
    return jsonResponse({
      image_url: url,
      captured_at: live.captured_at,
      state: live.state,
      last_seen_at: frame.last_seen_at,
      ends_at: new Date(endsAt).toISOString(),
    });
  }

  return jsonResponse({ error: "unknown_action" }, 400);
});
