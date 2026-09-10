// Media processing service: resizes photos and transcodes videos dispatched by
// the `complete-upload` Edge Function, then reports the result back to
// `media-processed-callback`. Nothing here ever sees the Supabase
// service-role key -- complete-upload does all the privileged DB writes
// itself (before dispatch: processing_status='processing'; after, via this
// service calling back with only scoped signed upload tokens and a shared
// callback secret).
import express from "express";
import sharp from "sharp";
import { spawn } from "child_process";
import fs from "fs/promises";
import os from "os";
import path from "path";
import { createClient } from "@supabase/supabase-js";
import { validateJob } from "./validate-job.js";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;
const SERVICE_TOKEN = process.env.MEDIA_PROCESSING_SERVICE_TOKEN || "";

// Display: large enough for a tablet display, small enough to keep offline
// cache/storage bounded. Thumbnail: grid/list previews in the Smile app.
const DISPLAY_MAX_EDGE = 2560;
const THUMBNAIL_MAX_EDGE = 400;

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/process", (req, res) => {
  const authHeader = req.headers["authorization"] || "";
  if (!SERVICE_TOKEN || authHeader !== `Bearer ${SERVICE_TOKEN}`) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const job = req.body;
  const validationError = validateJob(job);
  if (validationError) return res.status(400).json(validationError);

  // Accept immediately and do the actual work in the background -- a real
  // transcode can easily take longer than a typical request timeout (App
  // Runner's default is 100 seconds), and the caller (complete-upload) isn't
  // waiting synchronously for this to finish anyway.
  res.status(202).json({ accepted: true });
  runJob(job).catch((err) => {
    console.error(`[${job.media_item_id}] unhandled job error:`, err);
  });
});

async function runJob(job) {
  const workDir = await fs.mkdtemp(path.join(os.tmpdir(), "media-"));
  try {
    const result = job.media_type === "photo" ? await processPhoto(job) : await processVideo(job, workDir);
    await reportResult(job, { status: "ready", ...result });
    console.log(`[${job.media_item_id}] processing complete`);
  } catch (err) {
    console.error(`[${job.media_item_id}] processing failed:`, err);
    await reportResult(job, { status: "failed" }).catch((reportErr) => {
      console.error(`[${job.media_item_id}] failed to report failure:`, reportErr);
    });
  } finally {
    await fs.rm(workDir, { recursive: true, force: true }).catch(() => {});
  }
}

async function processPhoto(job) {
  const response = await fetch(job.download_url);
  if (!response.ok) throw new Error(`download failed: ${response.status}`);
  const originalBuffer = Buffer.from(await response.arrayBuffer());

  const displayBuffer = await sharp(originalBuffer)
    .rotate() // apply EXIF orientation before the pipeline strips metadata
    .resize({ width: DISPLAY_MAX_EDGE, height: DISPLAY_MAX_EDGE, fit: "inside", withoutEnlargement: true })
    .jpeg({ quality: 85 })
    .toBuffer();
  const displayMeta = await sharp(displayBuffer).metadata();
  await uploadResult(job, "media-display", job.display_path, job.display_upload_token, displayBuffer, "image/jpeg");

  let thumbnailPath;
  if (job.thumbnail_path && job.thumbnail_upload_token) {
    const thumbnailBuffer = await sharp(originalBuffer)
      .rotate()
      .resize({ width: THUMBNAIL_MAX_EDGE, height: THUMBNAIL_MAX_EDGE, fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();
    await uploadResult(
      job,
      "media-thumbnails",
      job.thumbnail_path,
      job.thumbnail_upload_token,
      thumbnailBuffer,
      "image/jpeg",
    );
    thumbnailPath = job.thumbnail_path;
  }

  return {
    display_path: job.display_path,
    thumbnail_path: thumbnailPath,
    width: displayMeta.width,
    height: displayMeta.height,
  };
}

async function processVideo(job, workDir) {
  const outputPath = path.join(workDir, "display.mp4");
  await transcode(job.download_url, outputPath);
  const fileBuffer = await fs.readFile(outputPath);
  await uploadResult(job, "media-display", job.display_path, job.display_upload_token, fileBuffer, "video/mp4");
  return { display_path: job.display_path };
}

// Conservative, guaranteed-widely-playable profile (per the plan: this caps
// both device compatibility risk and, since the kiosk caches every video
// fully for offline viewing, local storage use). ffmpeg reads straight from
// the signed download URL -- no separate download step. Same profile as
// smile_0_1's proven transcode-service.
function transcode(inputUrl, outputPath) {
  return new Promise((resolve, reject) => {
    const args = [
      "-y",
      "-i", inputUrl,
      "-vf", "scale='min(1280,iw)':-2",
      "-c:v", "libx264",
      "-profile:v", "main",
      "-level", "4.0",
      "-preset", "veryfast",
      "-crf", "23",
      "-maxrate", "2M",
      "-bufsize", "4M",
      "-c:a", "aac",
      "-b:a", "128k",
      "-movflags", "+faststart",
      outputPath,
    ];
    const ffmpeg = spawn("ffmpeg", args);
    let stderr = "";
    ffmpeg.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    ffmpeg.on("error", reject);
    ffmpeg.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited with code ${code}: ${stderr.slice(-2000)}`));
    });
  });
}

async function uploadResult(job, bucket, destPath, token, buffer, contentType) {
  const supabase = createClient(job.supabase_url, job.supabase_anon_key);
  const { error } = await supabase.storage.from(bucket).uploadToSignedUrl(destPath, token, buffer, { contentType });
  if (error) throw new Error(`upload failed (${bucket}): ${error.message}`);
}

async function reportResult(job, result) {
  const response = await fetch(job.callback_url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${job.supabase_anon_key}`,
      "X-Callback-Token": job.callback_token,
    },
    body: JSON.stringify({ media_item_id: job.media_item_id, ...result }),
  });
  if (!response.ok) {
    throw new Error(`callback responded ${response.status}: ${await response.text()}`);
  }
}

app.listen(PORT, () => {
  console.log(`media-processing-service listening on ${PORT}`);
});
