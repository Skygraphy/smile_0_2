// Prints a fresh 6-digit login code for a test person (creates the user
// if needed): what the mail would have brought. TESTSUITE project only.
//   deno run --allow-net --allow-env otp.ts anna.berger@example.com
import { asService, req, requireEnv } from "../../supabase/functions/_tests/helpers.ts";

const email = Deno.args[0];
if (!email?.endsWith("@example.com")) throw new Error("Nur Testadressen (@example.com).");
const { url } = requireEnv();
const link = () => req(`${url}/auth/v1/admin/generate_link`, asService({
  method: "POST",
  body: JSON.stringify({ type: "magiclink", email }),
}));
let { body } = await link();
if (!body?.email_otp) {
  await req(`${url}/auth/v1/admin/users`, asService({ method: "POST", body: JSON.stringify({ email, email_confirm: true }) }));
  ({ body } = await link());
}
if (!body?.email_otp) throw new Error(`Kein Code: ${JSON.stringify(body)}`);
console.log(body.email_otp);
