// Removes Storage files whose rows are gone (migrations/0062): every
// media_items/profiles delete -- also by cascade, e.g. an album purged from
// the trash or an account deleted -- queues its files here through the
// outbox, so no file outlives its photo ("niemals Leichen").
//
// Called only by the database; authenticated by the shared secret like
// purge-trash. Removing an already removed file is not an error.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";

const ALLOWED_BUCKETS = new Set(["media-originals", "media-display", "media-thumbnails", "avatars"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  let body: { files?: { bucket: string; path: string }[] };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const byBucket = new Map<string, string[]>();
  for (const f of body.files ?? []) {
    if (!ALLOWED_BUCKETS.has(f.bucket) || !f.path) continue;
    byBucket.set(f.bucket, [...(byBucket.get(f.bucket) ?? []), f.path]);
  }
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  let removed = 0;
  for (const [bucket, paths] of byBucket) {
    for (let i = 0; i < paths.length; i += 100) {
      const { data, error } = await supabaseAdmin.storage.from(bucket).remove(paths.slice(i, i + 100));
      // A failure goes back to the outbox, which retries the whole call.
      if (error) return jsonResponse({ error: "remove_failed", detail: error.message }, 500);
      removed += data?.length ?? 0;
    }
  }
  return jsonResponse({ status: "ok", removed });
});
