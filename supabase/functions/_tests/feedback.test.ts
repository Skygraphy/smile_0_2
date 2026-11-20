// Hilfe & Feedback (migrations/0113): anyone sends, only the operator
// (ops_alert_recipients) gets the push and the list; a retry with the same
// client_id stays one report; nobody reads reports through the API.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
  svc,
  invoke,
  asUser,
  createThrowawayUser,
  deleteUser,
  accessTokenFor,
  ensureProfile,
  createSpace,
  deleteSpace,
} from "./helpers.ts";

// A 1x1 JPEG.
const TINY_JPEG =
  "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=";

Deno.test("feedback reaches only the operator, once per client_id", async () => {
  requireEnv();
  const sender = await createThrowawayUser("fbsender");
  const ops = await createThrowawayUser("fbops");
  const other = await createThrowawayUser("fbother");
  let otherSpace: string | undefined;
  try {
    await ensureProfile(sender.id, "Ines Feedback");
    await ensureProfile(ops.id, "Ops Feedback");
    await ensureProfile(other.id, "Other Feedback");
    const ins = await svc("ops_alert_recipients", { method: "POST", body: JSON.stringify({ user_id: ops.id }) });
    assert(ins.status < 300, JSON.stringify(ins.body));

    const s = await accessTokenFor(sender.email);
    const o = await accessTokenFor(ops.email);
    const x = await accessTokenFor(other.email);

    // A Frame the sender cannot see is ignored.
    otherSpace = await createSpace(x.accessToken, "Fremder Space");
    const frame = await invoke("create-frame", x.accessToken, { space_id: otherSpace, name: "Fremd" });
    const foreignFrameId = frame.body.frame_id as string;

    assertEquals((await invoke("feedback", s.accessToken, { action: "am_ops" })).body.ops, false);
    assertEquals((await invoke("feedback", o.accessToken, { action: "am_ops" })).body.ops, true);

    const report = {
      action: "send",
      client_id: `test-${crypto.randomUUID()}`,
      kind: "problem",
      message: "Am Frame kommen die neuen Fotos nicht.",
      frame_id: foreignFrameId ?? null,
      device_info: { app_version: "0.0.19+1", device: "samsung SM-S942B", os: "Android 16", language: "de" },
      images: [TINY_JPEG],
    };
    const first = await invoke("feedback", s.accessToken, report);
    assertEquals(first.status, 200, JSON.stringify(first.body));
    const again = await invoke("feedback", s.accessToken, report);
    assertEquals(again.body.id, first.body.id, "a retry is the same report");

    // Not readable through the API, not even by the sender.
    const direct = await asUser("feedback_reports?select=id", s.accessToken);
    assertEquals(direct.body, []);

    // Only the operator lists.
    assertEquals((await invoke("feedback", s.accessToken, { action: "list" })).status, 403);
    const list = await invoke("feedback", o.accessToken, { action: "list" });
    assertEquals(list.status, 200);
    // deno-lint-ignore no-explicit-any
    const mine = (list.body.reports as any[]).filter((r) => r.id === first.body.id);
    assertEquals(mine.length, 1);
    assertEquals(mine[0].sender_name, "Ines Feedback");
    assertEquals(mine[0].sender_email, sender.email);
    assertEquals(mine[0].frame_info, null, "a foreign Frame is not attached");
    assertEquals(mine[0].image_urls.length, 1);
    assertEquals(mine[0].device_info.device, "samsung SM-S942B");

    // The push (Verlauf) went to the operator only.
    const opsNotes = (await svc(`user_notifications?user_id=eq.${ops.id}&select=title,data`)).body as { title: string }[];
    assertEquals(opsNotes.filter((n) => n.title === "Neue Meldung von Ines Feedback").length, 1);
    const senderNotes = (await svc(`user_notifications?user_id=eq.${sender.id}&select=title`)).body as unknown[];
    assertEquals(senderNotes.length, 0);

    // Erledigt and back.
    assertEquals((await invoke("feedback", s.accessToken, { action: "set_status", id: first.body.id, status: "done" })).status, 403);
    assertEquals((await invoke("feedback", o.accessToken, { action: "set_status", id: first.body.id, status: "done" })).status, 200);
    const row = (await svc(`feedback_reports?id=eq.${first.body.id}&select=status,done_at,image_paths`)).body as {
      status: string;
      done_at: string | null;
      image_paths: string[];
    }[];
    assertEquals(row[0].status, "done");
    assert(row[0].done_at);

    // Invalid input is refused.
    assertEquals((await invoke("feedback", s.accessToken, { action: "send", kind: "x", message: "a" })).status, 400);
    assertEquals((await invoke("feedback", s.accessToken, { action: "send", kind: "idea", message: "  " })).status, 400);

    // delete-account takes the reports and their pictures along.
    const del = await invoke("delete-account", s.accessToken, {});
    assertEquals(del.status, 200, JSON.stringify(del.body));
    const gone = (await svc(`feedback_reports?id=eq.${first.body.id}&select=id`)).body as unknown[];
    assertEquals(gone.length, 0);
  } finally {
    await svc(`ops_alert_recipients?user_id=eq.${ops.id}`, { method: "DELETE" });
    if (otherSpace) await deleteSpace(otherSpace);
    for (const u of [sender, ops, other]) await deleteUser(u.id).catch(() => {});
  }
});

