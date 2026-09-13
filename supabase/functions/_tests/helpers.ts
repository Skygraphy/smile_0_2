// Shared plumbing for the edge-function regression suite. Runs against the
// actual linked Supabase project (no local Docker/Postgres stack is
// available in this environment) -- every test creates its own throwaway
// auth user(s)/rows and tears them down in a `finally`, so running this
// suite is safe against real project data. See README.md for how to run
// it and which env vars it needs.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

export function requireEnv(): { url: string; serviceKey: string; anonKey: string } {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    throw new Error(
      "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY -- see supabase/functions/_tests/README.md",
    );
  }
  return { url: SUPABASE_URL, serviceKey: SERVICE_ROLE_KEY, anonKey: ANON_KEY };
}

export async function req(url: string, opts: RequestInit = {}): Promise<{ status: number; body: any }> {
  const res = await fetch(url, {
    ...opts,
    headers: { "Content-Type": "application/json", ...(opts.headers as Record<string, string> | undefined) },
  });
  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

export function asService(opts: RequestInit = {}): RequestInit {
  const { serviceKey } = requireEnv();
  return { ...opts, headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, ...(opts.headers as Record<string, string> | undefined) } };
}

export function svc(path: string, opts: RequestInit = {}) {
  const { url } = requireEnv();
  return req(`${url}/rest/v1/${path}`, asService(opts));
}

export function invoke(fn: string, accessToken: string, body: unknown) {
  const { url, anonKey } = requireEnv();
  return req(`${url}/functions/v1/${fn}`, {
    method: "POST",
    headers: { apikey: anonKey, Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify(body),
  });
}

export function asUser(path: string, accessToken: string, opts: RequestInit = {}) {
  const { url, anonKey } = requireEnv();
  return req(`${url}/rest/v1/${path}`, {
    ...opts,
    headers: { apikey: anonKey, Authorization: `Bearer ${accessToken}`, ...(opts.headers as Record<string, string> | undefined) },
  });
}

/** Creates a confirmed, password-less throwaway auth user. Caller must delete it (see deleteUser) in a finally block. */
export async function createThrowawayUser(prefix: string): Promise<{ id: string; email: string }> {
  const { url } = requireEnv();
  const email = `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
  const { body } = await req(`${url}/auth/v1/admin/users`, asService({
    method: "POST",
    body: JSON.stringify({ email, email_confirm: true }),
  }));
  if (!body?.id) throw new Error(`failed to create throwaway user: ${JSON.stringify(body)}`);
  return { id: body.id as string, email };
}

export async function deleteUser(userId: string): Promise<void> {
  const { url } = requireEnv();
  await req(`${url}/auth/v1/admin/users/${userId}`, asService({ method: "DELETE" }));
}

/** Real Supabase Auth session for any user (existing or throwaway), via magic-link + verify -- no password needed. */
export async function accessTokenFor(email: string): Promise<{ accessToken: string; userId: string }> {
  const { url, serviceKey, anonKey } = requireEnv();
  const { body: linkResp } = await req(`${url}/auth/v1/admin/generate_link`, asService({
    method: "POST",
    body: JSON.stringify({ type: "magiclink", email }),
  }));
  if (!linkResp?.hashed_token) throw new Error(`generate_link failed for ${email}: ${JSON.stringify(linkResp)}`);
  const { body: verifyResp } = await req(`${url}/auth/v1/verify`, {
    method: "POST",
    headers: { apikey: anonKey },
    body: JSON.stringify({ type: "magiclink", token_hash: linkResp.hashed_token }),
  });
  if (!verifyResp?.access_token) throw new Error(`verify failed for ${email}: ${JSON.stringify(verifyResp)}`);
  return { accessToken: verifyResp.access_token as string, userId: verifyResp.user.id as string };
}

/** Test fixtures -- real rows in the linked project, reused read-only by every test (never mutated in place). Override via env if the project's seed data ever changes. */
export const FIXTURES = {
  adminEmail: Deno.env.get("TEST_ADMIN_EMAIL") ?? "admin@skygraphy.com",
  omaSpaceId: Deno.env.get("TEST_OMA_SPACE_ID") ?? "6f3a1f25-e9c3-4c5e-83dd-557d3dc01615",
  // Real second Space (also owned by adminEmail) -- used by
  // multi_space_channels.test.ts for the "share a channel with a second
  // Space" scenario (0030_multi_space_channels.sql).
  opaSpaceId: Deno.env.get("TEST_OPA_SPACE_ID") ?? "27fbf71c-21a4-452f-a70d-abb39a003604",
  enkelkinderChannelId: Deno.env.get("TEST_ENKELKINDER_CHANNEL_ID") ?? "6785a8dd-772f-43c7-aa42-45e1ac5365a1",
  stammtischChannelId: Deno.env.get("TEST_STAMMTISCH_CHANNEL_ID") ?? "9c74b88f-a13f-4084-b2f6-2caf817830a7",
};
