// Checking the session and doing the work at once (2026-10-12, speed):
// auth.getUser() is a network round trip of its own; waiting for it before
// the first query made every screen ~0.2-0.4 s slower. The user id is read
// from the token right away, the queries run, and NOTHING is answered
// unless the server has confirmed exactly that user -- errors included
// (respond() below), so a forged token learns nothing.
//
// Only for read-only functions: no query may change anything before the
// session is confirmed.

/** The `sub` of a bearer JWT, unverified -- only together with verifyUser(). */
export function userIdFromToken(authHeader: string): string | null {
  try {
    const payload = authHeader.replace(/^Bearer\s+/i, "").split(".")[1];
    const json = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
    return typeof json.sub === "string" ? json.sub : null;
  } catch {
    return null;
  }
}

// deno-lint-ignore no-explicit-any
export function verifyUser(supabaseAsUser: any, claimedUserId: string): Promise<boolean> {
  return supabaseAsUser.auth
    .getUser()
    // deno-lint-ignore no-explicit-any
    .then(({ data, error }: any) => !error && data?.user?.id === claimedUserId)
    .catch(() => false);
}

/** A response that is only given once the session is confirmed. */
export function guardedResponder(
  verified: Promise<boolean>,
  jsonResponse: (body: unknown, status?: number) => Response,
) {
  return async (body: unknown, status = 200): Promise<Response> =>
    (await verified) ? jsonResponse(body, status) : jsonResponse({ error: "invalid_session" }, 401);
}
