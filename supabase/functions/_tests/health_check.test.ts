// Monitoring stage 1 (migrations/0065): the hourly health check tells a
// Frame's managers (and the operator) when it has been offline for over a
// day, once, and again when it is back.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
  svc,
  invoke,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
} from "./helpers.ts";

async function runHealthCheck(): Promise<void> {
  const before = (await svc(`internal_calls?fn=eq.health-check&select=id&order=id.desc&limit=1`)).body as { id: number }[];
  const lastId = before[0]?.id ?? 0;
  const run = await svc("rpc/invoke_internal", { method: "POST", body: JSON.stringify({ fn: "health-check", body: {} }) });
  assertEquals(run.status, 204, JSON.stringify(run.body));
  // Wait until pg_net has delivered it (the request id is set on send).
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    const { body } = await svc(`internal_calls?fn=eq.health-check&id=gt.${lastId}&select=sent_at`);
    if ((body as { sent_at: string | null }[]).some((c) => c.sent_at)) break;
  }
  await new Promise((r) => setTimeout(r, 8000)); // the function itself runs a few seconds
}

async function titles(userId: string): Promise<string[]> {
  const { body } = await svc(`user_notifications?user_id=eq.${userId}&select=title&order=created_at.desc`);
  return (body as { title: string }[]).map((r) => r.title);
}

Deno.test("a Frame offline for over a day is reported once, and again when it is back", async () => {
  requireEnv();
  const admin = await createThrowawayUser("hcadmin");
  let space: string | undefined;
  let frameId: string | undefined;
  try {
    await ensureProfile(admin.id, "HC Admin");
    const { accessToken } = await accessTokenFor(admin.email);
    space = await createSpace(accessToken, "HC Space");
    const frame = await invoke("create-frame", accessToken, { space_id: space, name: "HC Frame" });
    frameId = frame.body.frame_id as string;
    const twoDaysAgo = new Date(Date.now() - 48 * 3600 * 1000).toISOString();
    await svc(`frames?id=eq.${frameId}`, {
      method: "PATCH",
      body: JSON.stringify({ lifecycle_state: "active", last_seen_at: twoDaysAgo }),
    });

    await runHealthCheck();
    assertEquals((await titles(admin.id)).filter((t) => t === "Frame offline").length, 1);

    // A second run while it is still offline does not repeat it.
    await runHealthCheck();
    assertEquals((await titles(admin.id)).filter((t) => t === "Frame offline").length, 1);

    await svc(`frames?id=eq.${frameId}`, { method: "PATCH", body: JSON.stringify({ last_seen_at: new Date().toISOString() }) });
    await runHealthCheck();
    assertEquals((await titles(admin.id)).includes("Frame wieder online"), true);
  } finally {
    if (frameId) await svc(`health_alerts?key=eq.frame_offline:${frameId}`, { method: "DELETE" });
    if (space) await deleteSpace(space);
    await deleteUser(admin.id);
  }
});
