// Hilfe & Feedback (migrations/0113, 2026-11-20).
//
// Worked on in the Verwaltung on smileapp.app (migrations/0114, 2026-11-21).
//
//   send       anyone signed in: a problem, an idea or a question, up to 3
//              pictures (base64 JPEG), optionally about one of their Frames.
//              Goes as a push to the Super-Admin and Admins with Meldungen.
//   list       Verwaltung (Meldungen) only: all reports, newest first,
//              pictures signed.
//   set_status Verwaltung only: open / in_progress (taken by the caller) /
//              done (closed by the caller).
//   set_note   Verwaltung only: the internal note.
//
// Who is in the Verwaltung: admin_users (_shared/admin-access.ts).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { avatarPublicUrl } from "../_shared/profiles.ts";
import { adminAccess, feedbackAdminIds } from "../_shared/admin-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const KINDS = ["problem", "idea", "question"] as const;
const KIND_LABEL: Record<string, string> = { problem: "Etwas geht nicht", idea: "Idee oder Wunsch", question: "Frage" };
const MAX_IMAGES = 3;
const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

interface Body {
  action?: string;
  kind?: string;
  message?: string;
  frame_id?: string | null;
  device_info?: Record<string, unknown>;
  images?: string[];
  client_id?: string;
  id?: string;
  status?: string;
  note?: string | null;
  app_context?: { screen?: unknown; errors?: unknown };
}

// Where in the app and the last errors (migrations/0115): only plain,
// short strings are kept.
function cleanAppContext(raw: Body["app_context"]): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object") return null;
  const out: Record<string, unknown> = {};
  if (typeof raw.screen === "string" && raw.screen.trim()) out.screen = raw.screen.trim().slice(0, 200);
  if (Array.isArray(raw.errors)) {
    out.errors = raw.errors
      .filter((e): e is { at?: unknown; text?: unknown } => !!e && typeof e === "object")
      .filter((e) => typeof e.text === "string" && e.text.trim())
      .slice(0, 20)
      .map((e) => ({ at: typeof e.at === "string" ? e.at.slice(0, 40) : null, text: (e.text as string).slice(0, 500) }));
  }
  return Object.keys(out).length ? out : null;
}

const STATUSES = ["open", "in_progress", "done"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const asUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const user = userData.user;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const action = body.action ?? "send";
  if (action === "send") return await send(admin, asUser, user.id, user.email ?? null, body);

  const access = await adminAccess(admin, user.id);
  if (!access?.feedback) return jsonResponse({ error: "forbidden" }, 403);
  switch (action) {
    case "list":
      return await list(admin);
    case "set_status": {
      const status = body.status ?? "";
      if (!body.id || !STATUSES.includes(status)) return jsonResponse({ error: "invalid" }, 400);
      const now = new Date().toISOString();
      const patch: Record<string, unknown> = { status };
      if (status === "open") Object.assign(patch, { claimed_by: null, done_at: null, done_by: null });
      if (status === "in_progress") Object.assign(patch, { claimed_by: user.id, done_at: null, done_by: null });
      if (status === "done") Object.assign(patch, { done_at: now, done_by: user.id });
      const { data, error } = await admin.from("feedback_reports").update(patch).eq("id", body.id).select("id");
      if (error) return jsonResponse({ error: "update_failed" }, 500);
      if (!data?.length) return jsonResponse({ error: "not_found" }, 404);
      return jsonResponse({ status: "ok" });
    }
    case "set_note": {
      if (!body.id) return jsonResponse({ error: "invalid" }, 400);
      const note = (body.note ?? "").trim();
      if (note.length > 5000) return jsonResponse({ error: "invalid" }, 400);
      const { data, error } = await admin.from("feedback_reports").update({ note: note || null }).eq("id", body.id).select("id");
      if (error) return jsonResponse({ error: "update_failed" }, 500);
      if (!data?.length) return jsonResponse({ error: "not_found" }, 404);
      return jsonResponse({ status: "ok" });
    }
    default:
      return jsonResponse({ error: "unknown_action" }, 400);
  }
});

// deno-lint-ignore no-explicit-any
type Client = any;

async function send(
  admin: Client,
  asUser: Client,
  userId: string,
  email: string | null,
  body: Body,
): Promise<Response> {
  const kind = body.kind ?? "";
  const message = (body.message ?? "").trim();
  if (!(KINDS as readonly string[]).includes(kind)) return jsonResponse({ error: "invalid_kind" }, 400);
  if (message.length === 0 || message.length > 5000) return jsonResponse({ error: "invalid_message" }, 400);
  const images = body.images ?? [];
  if (images.length > MAX_IMAGES) return jsonResponse({ error: "too_many_images" }, 400);

  // Sent before and the answer got lost: the same report, once.
  if (body.client_id) {
    const { data: existing } = await admin.from("feedback_reports").select("id").eq("client_id", body.client_id).maybeSingle();
    if (existing) return jsonResponse({ status: "ok", id: existing.id });
  }

  // A Frame only if the sender may see it (RLS as the sender) -- and then
  // what the server knows about it right now.
  let frameId: string | null = null;
  let frameInfo: Record<string, unknown> | null = null;
  if (body.frame_id) {
    const { data: visible } = await asUser.from("frames").select("id").eq("id", body.frame_id).maybeSingle();
    if (visible) {
      const { data: f } = await admin
        .from("frames")
        .select("id, name, device_model, current_app_version, battery_level, last_seen_at, lifecycle_state, control_level, spaces(name)")
        .eq("id", body.frame_id)
        .maybeSingle();
      if (f) {
        frameId = f.id;
        frameInfo = {
          name: f.name,
          space: (f.spaces as { name?: string } | null)?.name ?? null,
          device_model: f.device_model,
          app_version: f.current_app_version,
          battery_level: f.battery_level,
          last_seen_at: f.last_seen_at,
          state: f.lifecycle_state,
          control_level: f.control_level,
        };
      }
    }
  }

  const { data: profile } = await admin.from("profiles").select("display_name").eq("user_id", userId).maybeSingle();
  const senderName = (profile?.display_name as string | null) ?? null;

  const id = crypto.randomUUID();
  const paths: string[] = [];
  for (let i = 0; i < images.length; i++) {
    let bytes: Uint8Array;
    try {
      bytes = decodeBase64(images[i]);
    } catch {
      return jsonResponse({ error: "invalid_image" }, 400);
    }
    if (bytes.length > MAX_IMAGE_BYTES) return jsonResponse({ error: "image_too_large" }, 400);
    const path = `${id}/${i + 1}.jpg`;
    const { error } = await admin.storage.from("feedback").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
    if (error) return jsonResponse({ error: "image_upload_failed" }, 500);
    paths.push(path);
  }

  const deviceInfo: Record<string, string> = {};
  for (const [k, v] of Object.entries(body.device_info ?? {})) {
    if (typeof v === "string" || typeof v === "number" || typeof v === "boolean") deviceInfo[k] = String(v).slice(0, 200);
  }

  const { error } = await admin.from("feedback_reports").insert({
    id,
    user_id: userId,
    sender_name: senderName,
    sender_email: email,
    kind,
    message,
    frame_id: frameId,
    frame_info: frameInfo,
    device_info: deviceInfo,
    image_paths: paths,
    client_id: body.client_id ?? null,
    app_context: cleanAppContext(body.app_context),
  });
  if (error) {
    if (paths.length > 0) await admin.storage.from("feedback").remove(paths);
    // The same client_id at the same moment (two retries at once).
    if (error.code === "23505") return jsonResponse({ status: "ok" });
    return jsonResponse({ error: "insert_failed" }, 500);
  }

  const ops = await feedbackAdminIds(admin);
  const preview = message.length > 120 ? `${message.slice(0, 117)}…` : message;
  await pushNotificationToUsers(
    admin,
    ops,
    { title: `Neue Meldung von ${senderName ?? "jemandem"}`, body: `${KIND_LABEL[kind]} · ${preview}` },
    { type: "feedback", report_id: id },
  );
  return jsonResponse({ status: "ok", id });
}

async function list(admin: Client): Promise<Response> {
  const { data: rows, error } = await admin
    .from("feedback_reports")
    .select("id, user_id, sender_name, sender_email, kind, message, frame_info, device_info, image_paths, status, created_at, done_at, claimed_by, done_by, note, app_context")
    .order("created_at", { ascending: false })
    .limit(300);
  if (error) return jsonResponse({ error: "list_failed" }, 500);

  const allPaths = (rows ?? []).flatMap((r: { image_paths: string[] }) => r.image_paths ?? []);
  const signed = new Map<string, string>();
  if (allPaths.length > 0) {
    const { data } = await admin.storage.from("feedback").createSignedUrls(allPaths, 3600);
    for (const s of data ?? []) if (s.path && s.signedUrl) signed.set(s.path, s.signedUrl);
  }
  // deno-lint-ignore no-explicit-any
  const all = (rows ?? []) as any[];
  const userIds = [...new Set(all.flatMap((r) => [r.user_id, r.claimed_by, r.done_by]).filter(Boolean))];
  const avatars = new Map<string, string | null>();
  const names = new Map<string, string | null>();
  if (userIds.length > 0) {
    const { data } = await admin.from("profiles").select("user_id, display_name, avatar_path").in("user_id", userIds);
    for (const p of data ?? []) {
      avatars.set(p.user_id as string, avatarPublicUrl(p.avatar_path as string | null));
      names.set(p.user_id as string, (p.display_name as string | null) ?? null);
    }
  }
  return jsonResponse({
    reports: (rows ?? []).map((r: Record<string, unknown>) => ({
      ...r,
      avatar_url: avatars.get(r.user_id as string) ?? null,
      claimed_by_name: r.claimed_by ? names.get(r.claimed_by as string) ?? null : null,
      done_by_name: r.done_by ? names.get(r.done_by as string) ?? null : null,
      image_urls: ((r.image_paths as string[]) ?? []).map((p) => signed.get(p)).filter(Boolean),
    })),
  });
}
