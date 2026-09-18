// Called by the Smile app to start an upload. Validates the caller is a
// member of the target channel (channel_members -- posting rights, see
// migrations/0031_architecture_reset.sql), pre-creates the media_items
// row, and returns a signed Storage upload URL/token -- the client never
// gets direct write access to the media-originals bucket.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024; // matches storage.file_size_limit in config.toml
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
  if (!body.channel_id || !body.media_type || !body.mime_type || !body.file_extension) {
    return jsonResponse({ error: "missing_fields" }, 400);
  }
  if (!["photo", "video"].includes(body.media_type)) {
    return jsonResponse({ error: "invalid_media_type" }, 400);
  }
  if (body.file_size_bytes && body.file_size_bytes > MAX_FILE_SIZE_BYTES) {
    return jsonResponse({ error: "file_too_large" }, 400);
  }
  if (body.preview_data_url && body.preview_data_url.length > MAX_PREVIEW_DATA_URL_LENGTH) {
    return jsonResponse({ error: "preview_too_large" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: membership } = await supabaseAdmin
    .from("channel_members")
    .select("user_id")
    .eq("channel_id", body.channel_id)
    .eq("user_id", userId)
    .maybeSingle();
  if (!membership) {
    return jsonResponse({ error: "not_a_channel_member" }, 403);
  }

  const mediaItemId = crypto.randomUUID();
  const storagePath = `${body.channel_id}/${mediaItemId}.${body.file_extension}`;

  const { data: mediaItem, error: insertError } = await supabaseAdmin
    .from("media_items")
    .insert({
      id: mediaItemId,
      channel_id: body.channel_id,
      sender_id: userId,
      media_type: body.media_type,
      storage_path_original: storagePath,
      mime_type: body.mime_type,
      file_size_bytes: body.file_size_bytes ?? null,
      preview_data_url: body.preview_data_url ?? null,
      processing_status: "uploaded",
    })
    .select()
    .single();

  if (insertError || !mediaItem) return jsonResponse({ error: "media_item_creation_failed" }, 500);

  const { data: signedUpload, error: signError } = await supabaseAdmin.storage
    .from("media-originals")
    .createSignedUploadUrl(storagePath);

  if (signError || !signedUpload) return jsonResponse({ error: "signed_url_failed" }, 500);

  return jsonResponse({
    media_item_id: mediaItem.id,
    storage_path: storagePath,
    signed_url: signedUpload.signedUrl,
    token: signedUpload.token,
  });
});
