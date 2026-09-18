// Best-effort "sync now" push to a set of Frames -- lets a fresh photo (or
// a delete) reach a Frame immediately instead of waiting for its next
// periodic poll. PushSyncSignal on the Smile-Frame side treats *any*
// incoming FCM message as a cue to run its already-scheduled sync loop
// immediately, so the payload just needs to arrive; its content doesn't
// matter beyond being non-empty. Never throws -- the periodic poll
// (get-media-batch) is the real delivery guarantee, this is purely a
// latency shortcut.
import { sendDataMessage } from "./fcm.ts";

// deno-lint-ignore no-explicit-any
export async function pushSyncNowToFrames(supabaseAdmin: any, frameIds: string[]): Promise<void> {
  if (frameIds.length === 0) return;
  const { data: frames } = await supabaseAdmin
    .from("frames")
    .select("fcm_token")
    .in("id", frameIds)
    .not("fcm_token", "is", null);

  await Promise.all(
    (frames ?? []).map((f: { fcm_token: string }) =>
      sendDataMessage(f.fcm_token, { type: "sync_now" }).catch(() => {}),
    ),
  );
}
