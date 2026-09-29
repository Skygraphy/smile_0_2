// The daily end of the 30-day trash (migrations/0048: pg_cron job
// 'smile-purge-trash' -> invoke_internal('purge-trash')). Whatever has been
// in the trash longer than TRASH_DAYS is deleted for good: photo files
// first (Storage doesn't cascade), then the row -- which cascades to
// everything else (channels, members, shares, Frames, photos' rows).
//
// Called only by the database; deployed with --no-verify-jwt and
// authenticated by the shared secret, like sync-fanout.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { removeChannelMediaFiles, TRASH_DAYS } from "../_shared/trash.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const cutoff = new Date(Date.now() - TRASH_DAYS * 24 * 3600 * 1000).toISOString();

  const [{ data: spaces }, { data: channels }] = await Promise.all([
    supabaseAdmin.from("spaces").select("id").lt("deleted_at", cutoff),
    supabaseAdmin.from("channels").select("id").lt("deleted_at", cutoff),
  ]);

  let purgedSpaces = 0;
  for (const space of spaces ?? []) {
    const { data: spaceChannels } = await supabaseAdmin.from("channels").select("id").eq("space_id", space.id);
    await removeChannelMediaFiles(supabaseAdmin, (spaceChannels ?? []).map((c: { id: string }) => c.id));
    const { error } = await supabaseAdmin.from("spaces").delete().eq("id", space.id);
    if (!error) purgedSpaces++;
  }

  let purgedChannels = 0;
  for (const channel of channels ?? []) {
    await removeChannelMediaFiles(supabaseAdmin, [channel.id as string]);
    const { error } = await supabaseAdmin.from("channels").delete().eq("id", channel.id);
    if (!error) purgedChannels++;
  }

  return jsonResponse({ status: "ok", purged_spaces: purgedSpaces, purged_channels: purgedChannels });
});
