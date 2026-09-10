import { test } from "node:test";
import assert from "node:assert/strict";
import { validateJob } from "./validate-job.js";

const baseJob = {
  media_item_id: "item-1",
  media_type: "photo",
  download_url: "https://example.test/download",
  display_path: "channel/item_display.jpg",
  display_upload_token: "token-1",
  supabase_url: "https://project.supabase.co",
  supabase_anon_key: "sb_publishable_test",
  callback_url: "https://project.supabase.co/functions/v1/media-processed-callback",
  callback_token: "callback-secret",
};

test("accepts a complete photo job", () => {
  assert.equal(validateJob(baseJob), null);
});

test("accepts a complete video job without thumbnail fields", () => {
  assert.equal(validateJob({ ...baseJob, media_type: "video" }), null);
});

test("rejects a job missing required fields", () => {
  const { media_item_id: _drop, ...incomplete } = baseJob;
  const result = validateJob(incomplete);
  assert.equal(result.error, "missing_fields");
  assert.deepEqual(result.fields, ["media_item_id"]);
});

test("rejects an invalid media_type", () => {
  const result = validateJob({ ...baseJob, media_type: "audio" });
  assert.equal(result.error, "invalid_media_type");
});

test("rejects a missing job entirely", () => {
  const result = validateJob(undefined);
  assert.equal(result.error, "missing_fields");
});
