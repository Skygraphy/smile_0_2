// One video job, start to finish, in its own short-lived AWS Fargate task
// (launched by index.js's /process for every video). The job arrives as JSON
// in the JOB environment variable -- the same job shape complete-upload
// sends for photos. Exits 0 when the result (or the failure) has been
// reported back to media-processed-callback, so the task always ends.
//
// Nothing here ever sees the Supabase service-role key: downloading uses the
// job's signed URL, uploading uses signed upload tokens -- fresh ones,
// requested from the callback right before uploading, because converting a
// long video can outlast the 2 hours the job's original tokens are valid.
import { createClient } from "@supabase/supabase-js";
import fs from "fs/promises";
import os from "os";
import path from "path";
import { posterFrame, probe, transcode, tusUpload } from "./video.js";

const job = JSON.parse(process.env.JOB ?? "{}");

async function callback(body) {
  const response = await fetch(job.callback_url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${job.supabase_anon_key}`,
      "X-Callback-Token": job.callback_token,
    },
    body: JSON.stringify({ media_item_id: job.media_item_id, ...body }),
  });
  if (!response.ok) throw new Error(`callback responded ${response.status}: ${await response.text()}`);
  return response.json();
}

async function main() {
  const workDir = await fs.mkdtemp(path.join(os.tmpdir(), "video-"));
  const videoPath = path.join(workDir, "display.mp4");
  const posterPath = path.join(workDir, "poster.jpg");
  try {
    console.log(`[${job.media_item_id}] transcoding`);
    await transcode(job.download_url, videoPath);
    await posterFrame(videoPath, posterPath);
    const meta = await probe(videoPath);

    const tokens = await callback({ action: "upload_tokens" });
    console.log(`[${job.media_item_id}] uploading ${(await fs.stat(videoPath)).size} bytes`);
    await tusUpload({
      supabaseUrl: job.supabase_url,
      apiKey: job.supabase_anon_key,
      bucket: "media-display",
      objectName: tokens.display_path,
      token: tokens.display_upload_token,
      filePath: videoPath,
      contentType: "video/mp4",
    });
    const supabase = createClient(job.supabase_url, job.supabase_anon_key);
    const { error } = await supabase.storage
      .from("media-thumbnails")
      .uploadToSignedUrl(tokens.thumbnail_path, tokens.thumbnail_upload_token, await fs.readFile(posterPath), {
        contentType: "image/jpeg",
      });
    if (error) throw new Error(`poster upload failed: ${error.message}`);

    await callback({
      status: "ready",
      display_path: tokens.display_path,
      thumbnail_path: tokens.thumbnail_path,
      ...meta,
    });
    console.log(`[${job.media_item_id}] done`);
  } catch (err) {
    console.error(`[${job.media_item_id}] failed:`, err);
    await callback({ status: "failed" }).catch((e) => console.error("could not report failure:", e));
    process.exitCode = 1;
  } finally {
    await fs.rm(workDir, { recursive: true, force: true }).catch(() => {});
  }
}

await main();
