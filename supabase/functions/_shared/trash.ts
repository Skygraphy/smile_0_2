// The 30-day trash (decision 2026-09-29, migrations/0048_trash.sql).
export const TRASH_DAYS = 30;

export function purgeAfter(deletedAt: string): string {
  return new Date(new Date(deletedAt).getTime() + TRASH_DAYS * 24 * 3600 * 1000).toISOString();
}

/**
 * Removes every photo FILE of these channels from Storage -- the rows go
 * with the cascade when the channel/Space row itself is deleted, the files
 * don't. Best-effort per batch: a file that's already missing never blocks
 * the purge.
 */
// deno-lint-ignore no-explicit-any
export async function removeChannelMediaFiles(supabaseAdmin: any, channelIds: string[]): Promise<void> {
  if (channelIds.length === 0) return;
  const { data: items } = await supabaseAdmin
    .from("media_items")
    .select("storage_path_original, storage_path_display, storage_path_thumbnail")
    .in("channel_id", channelIds);
  const byBucket: Record<string, string[]> = { "media-originals": [], "media-display": [], "media-thumbnails": [] };
  for (const item of items ?? []) {
    if (item.storage_path_original) byBucket["media-originals"].push(item.storage_path_original);
    if (item.storage_path_display) byBucket["media-display"].push(item.storage_path_display);
    if (item.storage_path_thumbnail) byBucket["media-thumbnails"].push(item.storage_path_thumbnail);
  }
  for (const [bucket, paths] of Object.entries(byBucket)) {
    for (let i = 0; i < paths.length; i += 100) {
      await supabaseAdmin.storage.from(bucket).remove(paths.slice(i, i + 100));
    }
  }
}
