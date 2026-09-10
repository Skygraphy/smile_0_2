// Best-effort "sync now" push to a set of devices -- mirrors notify-device's
// single-device nudge, but for the automatic case (a photo became ready, or
// got deleted) rather than a manual admin action. PushSyncSignal on the
// Smile-Frame side treats *any* incoming FCM message as a cue to run its
// already-scheduled sync loop immediately, so the payload just needs to
// arrive; its content doesn't matter beyond being non-empty. Never throws --
// the periodic poll (get-media-batch) is the real delivery guarantee, this
// is purely a latency shortcut.
import { sendDataMessage } from "./fcm.ts";

// deno-lint-ignore no-explicit-any
export async function pushSyncNowToDevices(supabaseAdmin: any, deviceIds: string[]): Promise<void> {
  if (deviceIds.length === 0) return;
  const { data: devices } = await supabaseAdmin
    .from("devices")
    .select("fcm_token")
    .in("id", deviceIds)
    .not("fcm_token", "is", null);

  await Promise.all(
    (devices ?? []).map((d: { fcm_token: string }) =>
      sendDataMessage(d.fcm_token, { type: "sync_now" }).catch(() => {}),
    ),
  );
}
