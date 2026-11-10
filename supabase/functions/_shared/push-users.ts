// Human-facing push notifications (smile-app) -- best-effort, never throws,
// but sends a real notification (title/body), unlike sync-fanout's silent
// data messages, and fans out to every token a
// user has registered (multiple devices/reinstalls).
import { sendNotification } from "./fcm.ts";
import { type Localized, type Notice, pushTexts } from "./push-texts.ts";

// deno-lint-ignore no-explicit-any
export async function pushNotificationToUsers(
  supabaseAdmin: any,
  userIds: string[],
  // A fixed text, or one written per recipient language (push-texts.ts,
  // profiles.language -- 2026-11-10).
  notification: Notice | Localized,
  data?: Record<string, string>,
  // Several pushes about the same thing in a row (a batch of photos) show as
  // ONE notification and ONE Verlauf entry that keeps being updated: with the
  // same key, the newer one replaces the older one within the window.
  options?: { collapseKey?: string; collapseWindowMinutes?: number },
): Promise<void> {
  if (userIds.length === 0) return;
  const collapseKey = options?.collapseKey;
  // Each person's language -- German when unknown.
  const languageOf = new Map<string, string>();
  if (typeof notification === "function") {
    const { data: profiles } = await supabaseAdmin.from("profiles").select("user_id, language").in("user_id", userIds);
    for (const row of profiles ?? []) languageOf.set(row.user_id as string, (row.language as string | null) ?? "de");
  }
  const rendered = new Map<string, Notice>();
  const textFor = (userId: string): Notice => {
    if (typeof notification !== "function") return notification;
    const language = languageOf.get(userId) ?? "de";
    if (!rendered.has(language)) rendered.set(language, notification(pushTexts(language)));
    return rendered.get(language)!;
  };
  if (collapseKey) data = { ...(data ?? {}), collapse_key: collapseKey };

  // Kept for 30 days as the "Verlauf" in Neuigkeiten (migrations/0059) --
  // independent of whether the person has a device to push to right now.
  // Best-effort: the push itself must not depend on it.
  try {
    if (collapseKey) {
      const since = new Date(Date.now() - (options?.collapseWindowMinutes ?? 10) * 60_000).toISOString();
      await supabaseAdmin
        .from("user_notifications")
        .delete()
        .in("user_id", userIds)
        .eq("data->>collapse_key", collapseKey)
        .gte("created_at", since);
    }
    await supabaseAdmin.from("user_notifications").insert(
      [...new Set(userIds)].map((userId) => ({
        user_id: userId,
        title: textFor(userId).title,
        body: textFor(userId).body,
        data: data ?? {},
      })),
    );
  } catch {
    // ignore
  }

  const { data: tokens } = await supabaseAdmin
    .from("user_push_tokens")
    .select("id, user_id, fcm_token")
    .in("user_id", userIds);

  await Promise.all(
    (tokens ?? []).map(async (t: { id: string; user_id: string; fcm_token: string }) => {
      try {
        await sendNotification(t.fcm_token, textFor(t.user_id), data, collapseKey);
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
