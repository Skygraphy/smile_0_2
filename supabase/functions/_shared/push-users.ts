// Human-facing push notifications (smile-app) -- best-effort, never throws,
// but sends a real notification (title/body), unlike sync-fanout's silent
// data messages, and fans out to every token a
// user has registered (multiple devices/reinstalls).
import { sendNotification } from "./fcm.ts";

// deno-lint-ignore no-explicit-any
export async function pushNotificationToUsers(
  supabaseAdmin: any,
  userIds: string[],
  notification: { title: string; body: string },
  data?: Record<string, string>,
): Promise<void> {
  if (userIds.length === 0) return;

  // Kept for 30 days as the "Verlauf" in Neuigkeiten (migrations/0059) --
  // independent of whether the person has a device to push to right now.
  // Best-effort: the push itself must not depend on it.
  try {
    await supabaseAdmin.from("user_notifications").insert(
      [...new Set(userIds)].map((userId) => ({
        user_id: userId,
        title: notification.title,
        body: notification.body,
        data: data ?? {},
      })),
    );
  } catch {
    // ignore
  }

  const { data: tokens } = await supabaseAdmin
    .from("user_push_tokens")
    .select("id, fcm_token")
    .in("user_id", userIds);

  await Promise.all(
    (tokens ?? []).map(async (t: { id: string; fcm_token: string }) => {
      try {
        await sendNotification(t.fcm_token, notification, data);
      } catch (err) {
        // Best-effort -- but a permanently dead
        // token (app uninstalled, token rotated) is worth pruning so it
        // doesn't keep failing forever on every future notification.
        const message = String(err);
        if (message.includes("UNREGISTERED") || message.includes("NOT_FOUND") || message.includes("INVALID_ARGUMENT")) {
          await supabaseAdmin.from("user_push_tokens").delete().eq("id", t.id);
        }
      }
    }),
  );
}
