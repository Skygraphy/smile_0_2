// Called by the Smile app to start an upload. Validates the caller is a
// member of the target channel (channel_members -- posting rights, see
// migrations/0031_architecture_reset.sql), pre-creates the media_items
// row, and returns a signed Storage upload URL/token -- the client never
// gets direct write access to the media-originals bucket.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";
import { processedPaths } from "../_shared/media-paths.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Photos stay small; videos have no length limit (decision 2026-10-01) --
// 50 GB is the project's Storage upload limit (Supabase Pro), i.e. hours
// of phone video. Videos go up resumably (TUS) with the same signed token.
const MAX_PHOTO_BYTES = 50 * 1024 * 1024;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024 * 1024;
// Matches the `preview_data_url` check constraint in
// migrations/0017_media_items_preview.sql -- this is a tiny blurry
// placeholder, not a real thumbnail, so a generous-looking cap still keeps
// rows small.
const MAX_PREVIEW_DATA_URL_LENGTH = 20000;

interface CreateUploadRequest {
  channel_id: string;
  media_type: "photo" | "video";
  mime_type: string;
  file_extension: string;
  file_size_bytes?: number;
  preview_data_url?: string;
  // The phone already made the display version (smile-app MediaShrink,
  // 2026-10-09/10): it also uploads the small picture (a video's poster
  // frame, a photo's thumbnail), and complete-upload takes both as they
  // are -- no worker, no waiting.
  client_encoded?: boolean;
  // Several at once (2026-10-10): one request for a whole selection of
  // photos instead of one each -- every Edge Function call costs ~1 s.
  // channel_id is shared; each item has the per-file fields above.
  items?: Omit<CreateUploadRequest, "channel_id" | "items">[];
}

type ItemRequest = Omit<CreateUploadRequest, "channel_id" | "items">;

function invalid(item: ItemRequest): string | null {
  if (!item.media_type || !item.mime_type || !item.file_extension) return "missing_fields";
  if (!["photo", "video"].includes(item.media_type)) return "invalid_media_type";
  const maxBytes = item.media_type === "video" ? MAX_VIDEO_BYTES : MAX_PHOTO_BYTES;
  if (item.file_size_bytes && item.file_size_bytes > maxBytes) return "file_too_large";
  if (item.preview_data_url && item.preview_data_url.length > MAX_PREVIEW_DATA_URL_LENGTH) return "preview_too_large";
  return null;
}

// deno-lint-ignore no-explicit-any
async function uploadSlots(supabaseAdmin: any, item: ItemRequest, mediaItemId: string, storagePath: string) {
  // Prepared on the phone (display version + thumbnail/poster): both go
  // straight to where they are served from, so complete-upload only has to
  // mark the item ready -- no copying (2026-10-10). The original slot stays
  // for the fallback (the server prepares it, as before).
  const { displayPath, thumbnailPath } = processedPaths(item.media_type, storagePath);
  const [original, display, thumb] = await Promise.all([
    supabaseAdmin.storage.from("media-originals").createSignedUploadUrl(storagePath),
    item.client_encoded ? supabaseAdmin.storage.from("media-display").createSignedUploadUrl(displayPath) : null,
    item.client_encoded ? supabaseAdmin.storage.from("media-thumbnails").createSignedUploadUrl(thumbnailPath) : null,
  ]);
  if (!original?.data) return null;
  return {
    media_item_id: mediaItemId,
    storage_path: storagePath,
    signed_url: original.data.signedUrl,
    token: original.data.token,
    ...(display?.data && thumb?.data
      ? {
        display_path: displayPath,
        display_token: display.data.token,
        thumb_path: thumbnailPath,
        thumb_token: thumb.data.token,
      }
      : {}),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);

  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: CreateUploadRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.channel_id) return jsonResponse({ error: "missing_fields" }, 400);
  const batch = Array.isArray(body.items);
  const items: ItemRequest[] = batch ? body.items! : [body];
  if (items.length === 0 || items.length > 50) return jsonResponse({ error: "invalid_items" }, 400);
  for (const item of items) {
    const problem = invalid(item);
    if (problem) return jsonResponse({ error: problem }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  // Posting rights = channel membership, the same rule media_items_insert's
  // RLS applies (single source, migrations/0047).
  const access = await resolveChannelAccess(supabaseAdmin, body.channel_id, userId);
  if (!access.isMember) {
    return jsonResponse({ error: "not_a_channel_member" }, 403);
  }

  // One insert for all; a millisecond apart, so they keep the order they
  // were picked in (the album sorts by created_at).
  const base = Date.now();
  const rows = items.map((item, index) => {
    const id = crypto.randomUUID();
    return {
      id,
      channel_id: body.channel_id,
      sender_id: userId,
      media_type: item.media_type,
      storage_path_original: `${body.channel_id}/${id}.${item.file_extension}`,
      mime_type: item.mime_type,
      file_size_bytes: item.file_size_bytes ?? null,
      preview_data_url: item.preview_data_url ?? null,
      processing_status: "uploaded",
      created_at: new Date(base + index).toISOString(),
    };
  });
  const { error: insertError } = await supabaseAdmin.from("media_items").insert(rows);
  if (insertError) return jsonResponse({ error: "media_item_creation_failed" }, 500);

  const slots = await Promise.all(
    rows.map((row, index) => uploadSlots(supabaseAdmin, items[index], row.id, row.storage_path_original)),
  );
  if (slots.some((s) => s === null)) {
    await supabaseAdmin.from("media_items").delete().in("id", rows.map((r) => r.id));
    return jsonResponse({ error: "signed_url_failed" }, 500);
  }
  if (batch) return jsonResponse({ items: slots });
  return jsonResponse(slots[0]);
});
