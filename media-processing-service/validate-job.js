// Pure request-shape validation, split out from index.js so it can be unit
// tested without importing the express app (which starts listening as a
// side effect of module load).
const REQUIRED_JOB_FIELDS = [
  "media_item_id",
  "media_type",
  "download_url",
  "display_path",
  "display_upload_token",
  "supabase_url",
  "supabase_anon_key",
  "callback_url",
  "callback_token",
];

export function validateJob(job) {
  const missing = REQUIRED_JOB_FIELDS.filter((key) => !job || !job[key]);
  if (missing.length > 0) return { error: "missing_fields", fields: missing };
  if (!["photo", "video"].includes(job.media_type)) return { error: "invalid_media_type" };
  return null;
}
