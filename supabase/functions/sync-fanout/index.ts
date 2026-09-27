// Called ONLY by the sync_notify() database trigger (via pg_net, see
// migrations/0041_fcm_sync.sql) -- never by a client. The trigger has
// already resolved exactly who is affected by a change; this just turns
// those user/Frame ids into FCM tokens and sends each one a silent data
// message. smile-app reloads whatever screen is showing (SyncBus);
// smile-frame treats any FCM message as "sync now" (PushSyncSignal).
//
// Deployed with --no-verify-jwt: the caller is the database, which has no
// user JWT. Authenticated instead by a shared secret the trigger reads from
// Vault (sync_fanout_secret) and this function from its own env.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";

interface SyncBody {
  table: string;
  op: string;
  users: string[];
  frames: string[];
  channel_ids: string[];
  space_ids: string[];
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: SyncBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const users = body.users ?? [];
  const frames = body.frames ?? [];

  // Comma-joined: FCM data payloads only carry string values.
  const data: Record<string, string> = {
    type: "sync",
    table: body.table ?? "",
    op: body.op ?? "",
    channel_ids: (body.channel_ids ?? []).join(","),
    space_ids: (body.space_ids ?? []).join(","),
  };

  const [{ data: userTokens }, { data: frameTokens }] = await Promise.all([
    users.length > 0
      ? supabaseAdmin.from("user_push_tokens").select("id, fcm_token").in("user_id", users)
      : Promise.resolve({ data: [] }),
    frames.length > 0
      ? supabaseAdmin.from("frames").select("fcm_token").in("id", frames).not("fcm_token", "is", null)
      : Promise.resolve({ data: [] }),
  ]);

  let sent = 0;
  await Promise.all([
    ...(userTokens ?? []).map(async (t: { id: string; fcm_token: string }) => {
      try {
        await sendDataMessage(t.fcm_token, data);
        sent++;
      } catch (err) {
        // Same pruning rule as push-users.ts -- a dead token would
        // otherwise fail again on every single future change.
        const message = String(err);
        if (message.includes("UNREGISTERED") || message.includes("NOT_FOUND") || message.includes("INVALID_ARGUMENT")) {
          await supabaseAdmin.from("user_push_tokens").delete().eq("id", t.id);
        }
      }
    }),
    ...(frameTokens ?? []).map(async (f: { fcm_token: string }) => {
      try {
        await sendDataMessage(f.fcm_token, { type: "sync_now" });
        sent++;
      } catch {
        // Best-effort -- the Frame's periodic poll is the real guarantee.
      }
    }),
  ]);

  return jsonResponse({ status: "ok", sent });
});
