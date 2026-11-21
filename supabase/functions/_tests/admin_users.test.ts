// Verwaltung (migrations/0114): one Super-Admin, entered directly; it adds,
// changes and removes Admins on the website; nobody can make, change or
// remove the Super-Admin through the API; rights decide what an Admin may do.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireEnv, svc, invoke, asUser, createThrowawayUser, deleteUser, accessTokenFor, ensureProfile } from "./helpers.ts";

Deno.test("admin_users: Super-Admin manages Admins, rights are enforced", async () => {
  requireEnv();
  const boss = await createThrowawayUser("adsuper");
  const helper = await createThrowawayUser("adhelper");
  const nobody = await createThrowawayUser("adnobody");
  try {
    await ensureProfile(boss.id, "Chef Verwaltung");
    await ensureProfile(helper.id, "Helfer Verwaltung");
    const ins = await svc("admin_users", { method: "POST", body: JSON.stringify({ user_id: boss.id, role: "super_admin" }) });
    assert(ins.status < 300, `a Super-Admin already exists in this project? ${JSON.stringify(ins.body)}`);

    const b = await accessTokenFor(boss.email);
    const h = await accessTokenFor(helper.email);
    const n = await accessTokenFor(nobody.email);

    // A second Super-Admin is refused by the database itself.
    const second = await svc("admin_users", { method: "POST", body: JSON.stringify({ user_id: nobody.id, role: "super_admin" }) });
    assert(second.status >= 400, "only one Super-Admin");

    // Not readable through the API.
    assertEquals((await asUser("admin_users?select=user_id", b.accessToken)).body, []);

    const meBoss = (await invoke("admin-users", b.accessToken, { action: "me" })).body;
    assertEquals([meBoss.role, meBoss.feedback, meBoss.vouchers, meBoss.manageAdmins], ["super_admin", true, true, true]);
    assertEquals((await invoke("admin-users", n.accessToken, { action: "me" })).status, 403);

    // Add an Admin by e-mail; an unknown address has no account.
    assertEquals((await invoke("admin-users", b.accessToken, { action: "add", email: "gibt-es-nicht@example.invalid" })).status, 404);
    const add = await invoke("admin-users", b.accessToken, { action: "add", email: helper.email.toUpperCase(), can_vouchers: true });
    assertEquals(add.status, 200, JSON.stringify(add.body));
    assertEquals((await invoke("admin-users", b.accessToken, { action: "add", email: helper.email })).status, 409);

    const meHelper = (await invoke("admin-users", h.accessToken, { action: "me" })).body;
    assertEquals([meHelper.role, meHelper.feedback, meHelper.vouchers, meHelper.manageAdmins], ["admin", false, true, false]);
    // An Admin cannot manage Admins and has no Meldungen yet.
    assertEquals((await invoke("admin-users", h.accessToken, { action: "list" })).status, 403);
    assertEquals((await invoke("admin-users", h.accessToken, { action: "add", email: nobody.email })).status, 403);
    assertEquals((await invoke("feedback", h.accessToken, { action: "list" })).status, 403);
    assertEquals((await invoke("voucher-admin", h.accessToken, { action: "list" })).status, 200);

    // Tick Meldungen, untick Gutscheine.
    assertEquals((await invoke("admin-users", b.accessToken, { action: "update", user_id: helper.id, can_feedback: true, can_vouchers: false })).status, 200);
    assertEquals((await invoke("feedback", h.accessToken, { action: "list" })).status, 200);
    assertEquals((await invoke("voucher-admin", h.accessToken, { action: "list" })).status, 403);

    // list shows both, Super-Admin first, with name and e-mail.
    // deno-lint-ignore no-explicit-any
    const admins = (await invoke("admin-users", b.accessToken, { action: "list" })).body.admins as any[];
    const mine = admins.filter((a) => a.user_id === boss.id || a.user_id === helper.id);
    assertEquals(mine.map((a) => a.role), ["super_admin", "admin"]);
    assertEquals(mine[1].name, "Helfer Verwaltung");
    assertEquals(mine[1].email, helper.email);

    // The Super-Admin row is never touched through the API.
    assertEquals((await invoke("admin-users", b.accessToken, { action: "update", user_id: boss.id, can_feedback: false })).status, 404);
    assertEquals((await invoke("admin-users", b.accessToken, { action: "remove", user_id: boss.id })).status, 404);
    assertEquals(((await invoke("admin-users", b.accessToken, { action: "me" })).body).role, "super_admin");

    // Remove the Admin: no access any more.
    assertEquals((await invoke("admin-users", b.accessToken, { action: "remove", user_id: helper.id })).status, 200);
    assertEquals((await invoke("admin-users", h.accessToken, { action: "me" })).status, 403);
    assertEquals((await invoke("feedback", h.accessToken, { action: "list" })).status, 403);
  } finally {
    await svc(`admin_users?user_id=in.(${boss.id},${helper.id},${nobody.id})`, { method: "DELETE" });
    for (const u of [boss, helper, nobody]) await deleteUser(u.id).catch(() => {});
  }
});
