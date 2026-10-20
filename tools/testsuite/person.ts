// Creates a test person directly (no device): user, profile, optional
// Smile name. TESTSUITE project only.
//   deno run --allow-net --allow-env person.ts paul.berger@example.com "Paul Berger" paul.berger
import { asService, req, requireEnv, svc } from "../../supabase/functions/_tests/helpers.ts";

const [email, name, handle] = Deno.args;
if (!email?.endsWith("@example.com") || !name) throw new Error("person.ts <email@example.com> <Name> [handle]");
const { url } = requireEnv();
let { body } = await req(`${url}/auth/v1/admin/users`, asService({ method: "POST", body: JSON.stringify({ email, email_confirm: true }) }));
let id = body?.id as string | undefined;
if (!id) {
  const list = await req(`${url}/auth/v1/admin/users?per_page=1000`, asService());
  id = list.body.users.find((u: { email: string }) => u.email === email)?.id;
}
if (!id) throw new Error(`Kein User: ${JSON.stringify(body)}`);
const res = await svc("profiles", {
  method: "POST",
  headers: { Prefer: "resolution=merge-duplicates" },
  body: JSON.stringify({ user_id: id, display_name: name, ...(handle ? { handle } : {}) }),
});
if (res.status >= 300) throw new Error(`Profil: ${res.status} ${JSON.stringify(res.body)}`);
console.log(id);
