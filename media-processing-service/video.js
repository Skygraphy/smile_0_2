// Video processing for videos of any length (decision 2026-10-01) -- run by
// worker.js inside its own short-lived AWS Fargate task, never inside the
// App Runner service: App Runner throttles CPU once a request has been
// answered and has 2 GB of RAM, so a long transcode there would crawl or
// crash. Everything here streams through files on the task's disk; no
// video is ever held in memory as a whole.
import { spawn } from "child_process";
import fs from "fs/promises";
import { createReadStream } from "fs";

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args);
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (c) => (stdout += c.toString()));
    child.stderr.on("data", (c) => (stderr += c.toString()));
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolve(stdout) : reject(new Error(`${cmd} exited with ${code}: ${stderr.slice(-2000)}`)),
    );
  });
}

// Conservative, widely playable profile: 720p max, H.264 main 8-bit, AAC --
// the Frame caches every video for offline playback, so this also bounds
// its storage (about 1 GB per hour). ffmpeg reads straight from the signed
// download URL. Same base profile as smile_0_1's proven transcode-service.
//
// Phones record HDR by default now (found 2026-10-01: a Samsung clip was
// HEVC Main 10, BT.2020, HLG) -- 10-bit input must be tone-mapped down to
// SDR, or it either fails ("main profile doesn't support a bit depth of
// 10") or looks washed out. So the input is probed first.
export async function transcode(inputUrl, outputPath) {
  const hdr = await isHdr(inputUrl);
  const scale = "scale='min(1280,iw)':-2";
  const filters = hdr
    ? [
        "zscale=t=linear:npl=100",
        "format=gbrpf32le",
        "zscale=p=bt709",
        "tonemap=tonemap=hable:desat=0",
        "zscale=t=bt709:m=bt709:r=tv",
        scale,
        "format=yuv420p",
      ].join(",")
    : `${scale},format=yuv420p`;
  return run("ffmpeg", [
    "-y",
    "-i", inputUrl,
    "-vf", filters,
    "-c:v", "libx264",
    "-profile:v", "main",
    "-level", "4.0",
    "-preset", "veryfast",
    "-crf", "23",
    "-maxrate", "2M",
    "-bufsize", "4M",
    "-colorspace", "bt709",
    "-color_primaries", "bt709",
    "-color_trc", "bt709",
    "-c:a", "aac",
    "-b:a", "128k",
    "-movflags", "+faststart",
    outputPath,
  ]);
}

/** HDR = PQ (smpte2084) or HLG (arib-std-b67) transfer, as phones record it. */
export async function isHdr(inputUrl) {
  const out = await run("ffprobe", [
    "-v", "error",
    "-select_streams", "v:0",
    "-show_entries", "stream=color_transfer",
    "-of", "json",
    inputUrl,
  ]);
  const transfer = JSON.parse(out).streams?.[0]?.color_transfer ?? "";
  return transfer === "smpte2084" || transfer === "arib-std-b67";
}

/** A poster frame for the feed: one second in (or the very first frame of a shorter clip). */
export async function posterFrame(videoPath, outputPath) {
  const grab = (at) =>
    run("ffmpeg", ["-y", "-ss", at, "-i", videoPath, "-frames:v", "1", "-vf", "scale='min(400,iw)':-2", "-q:v", "3", outputPath]);
  try {
    await grab("1");
    await fs.access(outputPath);
  } catch {
    await grab("0");
  }
}

/** Width, height and duration of the converted video. */
export async function probe(videoPath) {
  const out = await run("ffprobe", [
    "-v", "error",
    "-select_streams", "v:0",
    "-show_entries", "stream=width,height:format=duration",
    "-of", "json",
    videoPath,
  ]);
  const info = JSON.parse(out);
  return {
    width: info.streams?.[0]?.width,
    height: info.streams?.[0]?.height,
    duration_seconds: info.format?.duration ? Number(info.format.duration) : undefined,
  };
}

const CHUNK = 6 * 1024 * 1024; // Supabase requires exactly 6 MB per TUS chunk (except the last)

/**
 * Resumable (TUS) upload of a file of any size into Supabase Storage,
 * authorised by a signed upload token (x-signature) -- same protocol the
 * Smile app uses for uploading originals (resumable_upload.dart).
 */
export async function tusUpload({ supabaseUrl, apiKey, bucket, objectName, token, filePath, contentType }) {
  const size = (await fs.stat(filePath)).size;
  const b64 = (v) => Buffer.from(v).toString("base64");
  const headers = { apikey: apiKey, "x-signature": token, "Tus-Resumable": "1.0.0" };
  const created = await fetch(`${supabaseUrl}/storage/v1/upload/resumable/sign`, {
    method: "POST",
    headers: {
      ...headers,
      "Upload-Length": String(size),
      "Upload-Metadata": `bucketName ${b64(bucket)},objectName ${b64(objectName)},contentType ${b64(contentType)}`,
      "x-upsert": "true",
    },
  });
  const location = created.headers.get("location");
  if (created.status !== 201 || !location) {
    throw new Error(`resumable upload refused: ${created.status} ${await created.text()}`);
  }

  let offset = 0;
  let failures = 0;
  while (offset < size) {
    try {
      const chunk = await readChunk(filePath, offset, Math.min(CHUNK, size - offset));
      const res = await fetch(location, {
        method: "PATCH",
        headers: { ...headers, "Upload-Offset": String(offset), "Content-Type": "application/offset+octet-stream" },
        body: chunk,
      });
      if (res.status !== 204) throw new Error(`chunk at ${offset}: ${res.status} ${await res.text()}`);
      offset = Number(res.headers.get("upload-offset") ?? offset + chunk.length);
      failures = 0;
    } catch (err) {
      if (++failures > 8) throw err;
      await new Promise((r) => setTimeout(r, Math.min(2000 * failures, 30000)));
      const head = await fetch(location, { method: "HEAD", headers }).catch(() => null);
      const serverOffset = head ? Number(head.headers.get("upload-offset")) : NaN;
      if (!Number.isNaN(serverOffset)) offset = serverOffset;
    }
  }
}

function readChunk(filePath, start, length) {
  return new Promise((resolve, reject) => {
    const parts = [];
    createReadStream(filePath, { start, end: start + length - 1 })
      .on("data", (d) => parts.push(d))
      .on("end", () => resolve(Buffer.concat(parts)))
      .on("error", reject);
  });
}

