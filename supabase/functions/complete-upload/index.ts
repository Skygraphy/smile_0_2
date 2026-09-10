// Called by the Smile app once the raw bytes have been uploaded to the
// signed URL from create-upload. Dispatches to the external
// media-processing-service (sharp for photos, ffmpeg for videos -- Edge
// Functions can't run either) and returns immediately; the service reports
// the result back via media-processed-callback. If the service isn't
// configured yet (no MEDIA_PROCESSING_SERVICE_URL secret), photos fall back
// to the old passthrough copy and videos stay "uploaded" -- same graceful
// degradation smile_0_1 used for an unconfigured transcode step.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fanOutToDevices } from "../_shared/media-fanout.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const processingServiceUrl = Deno.env.get("MEDIA_PROCESSING_SERVICE_URL");
const processingServiceToken = Deno.env.get("MEDIA_PROCESSING_SERVICE_TOKEN");
const processingCallbackToken = Deno.env.get("MEDIA_PROCESSING_CALLBACK_TOKEN");
// The project's publishable (anon) key -- safe to hand to an external
// service since it's meant to be public, unlike serviceRoleKey above.
// Stored as its own secret (mirrors smile_0_1's TRANSCODE_STORAGE_KEY)
// rather than trusting a CLI-injected anon-key env var.
const processingStorageKey = Deno.env.get("MEDIA_PROCESSING_STORAGE_KEY") ?? "";

interface CompleteUploadRequest {
  media_item_id: string;
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

  let body: CompleteUploadRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.media_item_id) return jsonResponse({ error: "media_item_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: mediaItem, error: fetchError } = await supabaseAdmin
    .from("media_items")
    .select("*")
    .eq("id", body.media_item_id)
    .eq("sender_id", userData.user.id)
    .maybeSingle();

  if (fetchError || !mediaItem) return jsonResponse({ error: "media_item_not_found" }, 404);

  const processingConfigured = Boolean(processingServiceUrl && processingServiceToken && processingCallbackToken);

  if (!processingConfigured) {
    if (mediaItem.media_type === "photo") {
      const { error: copyError } = await supabaseAdmin.storage
        .from("media-originals")
        .copy(mediaItem.storage_path_original, mediaItem.storage_path_original, {
          destinationBucket: "media-display",
        });
      if (copyError) {
        await supabaseAdmin.from("media_items").update({ processing_status: "failed" }).eq("id", mediaItem.id);
        return jsonResponse({ error: "copy_failed", detail: copyError.message }, 500);
      }
      const { error: updateError } = await supabaseAdmin
        .from("media_items")
        .update({ storage_path_display: mediaItem.storage_path_original, processing_status: "ready" })
        .eq("id", mediaItem.id);
      if (updateError) return jsonResponse({ error: "update_failed" }, 500);
      await fanOutToDevices(supabaseAdmin, mediaItem.id, mediaItem.channel_id);
      return jsonResponse({ status: "ready" });
    }
    return jsonResponse({ status: "pending_processing", detail: "media_processing_service_not_configured" });
  }

  const { data: downloadData, error: downloadError } = await supabaseAdmin.storage
    .from("media-originals")
    .createSignedUrl(mediaItem.storage_path_original, 60 * 60); // 1h -- plenty for a processing job
  if (downloadError || !downloadData) return jsonResponse({ error: "download_url_failed" }, 500);

  const extMatch = mediaItem.storage_path_original.match(/\.[^./]+$/);
  const originalExt = extMatch ? extMatch[0] : "";
  const basePath = mediaItem.storage_path_original.slice(
    0,
    mediaItem.storage_path_original.length - originalExt.length,
  );
  const displayPath = `${basePath}_display${mediaItem.media_type === "video" ? ".mp4" : originalExt || ".jpg"}`;
  const thumbnailPath = mediaItem.media_type === "photo" ? `${basePath}_thumb${originalExt || ".jpg"}` : null;

  const { data: displayUpload, error: displayUploadError } = await supabaseAdmin.storage
    .from("media-display")
    .createSignedUploadUrl(displayPath);
  if (displayUploadError || !displayUpload) return jsonResponse({ error: "display_upload_url_failed" }, 500);

  let thumbnailUpload: { token: string } | null = null;
  if (thumbnailPath) {
    const { data: tUpload, error: tError } = await supabaseAdmin.storage
      .from("media-thumbnails")
      .createSignedUploadUrl(thumbnailPath);
    if (tError || !tUpload) return jsonResponse({ error: "thumbnail_upload_url_failed" }, 500);
    thumbnailUpload = tUpload;
  }

  await supabaseAdmin.from("media_items").update({ processing_status: "processing" }).eq("id", mediaItem.id);

  try {
    const dispatchResponse = await fetch(processingServiceUrl!, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${processingServiceToken}`,
      },
      body: JSON.stringify({
        media_item_id: mediaItem.id,
        media_type: mediaItem.media_type,
        download_url: downloadData.signedUrl,
        display_path: displayPath,
        display_upload_token: displayUpload.token,
        thumbnail_path: thumbnailPath,
        thumbnail_upload_token: thumbnailUpload?.token ?? null,
        supabase_url: supabaseUrl,
        supabase_anon_key: processingStorageKey,
        callback_url: `${supabaseUrl}/functions/v1/media-processed-callback`,
        callback_token: processingCallbackToken,
      }),
    });
    if (!dispatchResponse.ok) {
      throw new Error(`processing service responded ${dispatchResponse.status}`);
    }
  } catch (err) {
    // Dispatch itself failed (service unreachable, rejected the job, etc) --
    // mark it failed now rather than leaving it stuck at "processing"
    // forever with nothing ever going to complete it.
    await supabaseAdmin.from("media_items").update({ processing_status: "failed" }).eq("id", mediaItem.id);
    return jsonResponse({ error: "processing_dispatch_failed", detail: String(err) }, 502);
  }

  return jsonResponse({ status: "processing" });
});
