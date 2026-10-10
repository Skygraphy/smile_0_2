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
import { announceReadyPhoto } from "../_shared/media-fanout.ts";
import { clientPosterPath, processedPaths } from "../_shared/media-paths.ts";

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
  // See create-upload: the video is already in the display format.
  client_encoded?: boolean;
  // Both files were uploaded straight to media-display/media-thumbnails.
  direct?: boolean;
  width?: number;
  height?: number;
  duration_seconds?: number;
  // The size actually uploaded: the phone registers a video before it has
  // finished converting it (smile-app MediaService.uploadVideo).
  file_size_bytes?: number;
  // Several prepared (direct) uploads at once (2026-10-10) -- one request
  // for a whole selection of photos.
  items?: Omit<CompleteUploadRequest, "items">[];
}

/** Above this, a "converted" upload is not trusted and goes through the worker. */
const MAX_CLIENT_ENCODED_BYTES = 500 * 1024 * 1024;
const MAX_CLIENT_ENCODED_PHOTO_BYTES = 10 * 1024 * 1024;

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
  if (Array.isArray(body.items)) return completeBatch(body.items, userData.user.id);
  if (!body.media_item_id) return jsonResponse({ error: "media_item_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: mediaItem, error: fetchError } = await supabaseAdmin
    .from("media_items")
    .select("*")
    .eq("id", body.media_item_id)
    .eq("sender_id", userData.user.id)
    .maybeSingle();

  if (fetchError || !mediaItem) return jsonResponse({ error: "media_item_not_found" }, 404);
  if (body.file_size_bytes && body.file_size_bytes > 0 && body.file_size_bytes !== mediaItem.file_size_bytes) {
    mediaItem.file_size_bytes = Math.round(body.file_size_bytes);
    await supabaseAdmin.from("media_items").update({ file_size_bytes: mediaItem.file_size_bytes }).eq("id", mediaItem.id);
  }

  // A video the phone already converted (2026-10-09): taken as it is --
  // ready in a second instead of waiting ~30 s for a worker task to start.
  // Falls through to the worker if anything about it doesn't fit.
  const clientVideo = mediaItem.media_type === "video" && mediaItem.mime_type === "video/mp4" &&
    (mediaItem.file_size_bytes ?? 0) <= MAX_CLIENT_ENCODED_BYTES;
  const clientPhoto = mediaItem.media_type === "photo" && mediaItem.mime_type === "image/jpeg" &&
    (mediaItem.file_size_bytes ?? 0) <= MAX_CLIENT_ENCODED_PHOTO_BYTES;
  if (body.client_encoded && body.direct && (clientVideo || clientPhoto)) {
    // Already where they are served from: only mark it ready.
    const { displayPath, thumbnailPath } = processedPaths(mediaItem.media_type, mediaItem.storage_path_original);
    const { error: updateError } = await supabaseAdmin
      .from("media_items")
      .update({
        storage_path_display: displayPath,
        storage_path_thumbnail: thumbnailPath,
        processing_status: "ready",
        ...(body.width ? { width: Math.round(body.width) } : {}),
        ...(body.height ? { height: Math.round(body.height) } : {}),
        ...(body.duration_seconds ? { duration_seconds: body.duration_seconds } : {}),
      })
      .eq("id", mediaItem.id);
    if (!updateError) {
      const announce = announceReadyPhoto(supabaseAdmin, mediaItem.id, mediaItem.channel_id);
      // deno-lint-ignore no-explicit-any
      const runtime = (globalThis as any).EdgeRuntime;
      if (runtime?.waitUntil) runtime.waitUntil(announce);
      else await announce;
      return jsonResponse({ status: "ready" });
    }
    console.error("direct upload could not be marked ready", updateError);
  }

  if (body.client_encoded && (clientVideo || clientPhoto)) {
    const { displayPath, thumbnailPath } = processedPaths(mediaItem.media_type, mediaItem.storage_path_original);
    const posterPath = clientPosterPath(mediaItem.storage_path_original);
    const { error: videoCopyError } = await supabaseAdmin.storage
      .from("media-originals")
      .copy(mediaItem.storage_path_original, displayPath, { destinationBucket: "media-display" });
    const { error: posterCopyError } = await supabaseAdmin.storage
      .from("media-originals")
      .copy(posterPath, thumbnailPath, { destinationBucket: "media-thumbnails" });
    if (!videoCopyError && !posterCopyError) {
      const { error: updateError } = await supabaseAdmin
        .from("media_items")
        .update({
          storage_path_display: displayPath,
          storage_path_thumbnail: thumbnailPath,
          processing_status: "ready",
          ...(body.width ? { width: Math.round(body.width) } : {}),
          ...(body.height ? { height: Math.round(body.height) } : {}),
          ...(body.duration_seconds ? { duration_seconds: body.duration_seconds } : {}),
        })
        .eq("id", mediaItem.id);
      if (!updateError) {
        // The phone hears "ready" at once; the cleanup (its copy now lives
        // in media-thumbnails) and the pushes to the others run on after.
        const after = (async () => {
          await supabaseAdmin.storage.from("media-originals").remove([posterPath]);
          await announceReadyPhoto(supabaseAdmin, mediaItem.id, mediaItem.channel_id);
        })();
        // deno-lint-ignore no-explicit-any
        const runtime = (globalThis as any).EdgeRuntime;
        if (runtime?.waitUntil) runtime.waitUntil(after);
        else await after;
        return jsonResponse({ status: "ready" });
      }
    }
    console.error("client-encoded upload fell back to the worker", videoCopyError, posterCopyError);
  }

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
      await announceReadyPhoto(supabaseAdmin, mediaItem.id, mediaItem.channel_id);
      return jsonResponse({ status: "ready" });
    }
    return jsonResponse({ status: "pending_processing", detail: "media_processing_service_not_configured" });
  }

  const { data: downloadData, error: downloadError } = await supabaseAdmin.storage
    .from("media-originals")
    // A photo job takes seconds; a video of any length (decision
    // 2026-10-01) can take hours to convert, so its worker gets a day.
    .createSignedUrl(mediaItem.storage_path_original, mediaItem.media_type === "video" ? 24 * 60 * 60 : 60 * 60);
  if (downloadError || !downloadData) return jsonResponse({ error: "download_url_failed" }, 500);

  // Videos get a poster frame as their thumbnail too (the media worker
  // extracts it), so every ready item has an image for the feed.
  const { displayPath, thumbnailPath } = processedPaths(mediaItem.media_type, mediaItem.storage_path_original);

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

/**
 * Prepared uploads whose files are already in media-display and
 * media-thumbnails: marked ready together, one push for the whole
 * selection (it counts the batch itself, see media-fanout.ts).
 */
async function completeBatch(items: Omit<CompleteUploadRequest, "items">[], userId: string) {
  if (items.length === 0 || items.length > 50) return jsonResponse({ error: "invalid_items" }, 400);
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const ids = items.map((i) => i.media_item_id);
  const { data: rows } = await supabaseAdmin
    .from("media_items")
    .select("id, channel_id, media_type, mime_type, storage_path_original")
    .in("id", ids)
    .eq("sender_id", userId);
  const byId = new Map((rows ?? []).map((r: { id: string }) => [r.id, r]));
  const results: { media_item_id: string; status: string }[] = [];
  const announced = new Map<string, string>();
  for (const item of items) {
    // deno-lint-ignore no-explicit-any
    const row = byId.get(item.media_item_id) as any;
    const prepared = row &&
      ((row.media_type === "photo" && row.mime_type === "image/jpeg") ||
        (row.media_type === "video" && row.mime_type === "video/mp4"));
    if (!prepared) {
      results.push({ media_item_id: item.media_item_id, status: "not_found" });
      continue;
    }
    const { displayPath, thumbnailPath } = processedPaths(row.media_type, row.storage_path_original);
    const { error } = await supabaseAdmin
      .from("media_items")
      .update({
        storage_path_display: displayPath,
        storage_path_thumbnail: thumbnailPath,
        processing_status: "ready",
        ...(item.width ? { width: Math.round(item.width) } : {}),
        ...(item.height ? { height: Math.round(item.height) } : {}),
        ...(item.duration_seconds ? { duration_seconds: item.duration_seconds } : {}),
        ...(item.file_size_bytes ? { file_size_bytes: Math.round(item.file_size_bytes) } : {}),
      })
      .eq("id", row.id);
    results.push({ media_item_id: row.id, status: error ? "failed" : "ready" });
    if (!error) announced.set(row.channel_id, row.id);
  }
  const announce = Promise.all(
    [...announced].map(([channelId, lastId]) => announceReadyPhoto(supabaseAdmin, lastId, channelId)),
  );
  // deno-lint-ignore no-explicit-any
  const runtime = (globalThis as any).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(announce);
  else await announce;
  return jsonResponse({ items: results });
}
