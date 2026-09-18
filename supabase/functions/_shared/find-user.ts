// Resolves an email to an auth.users id -- needed by every "invite a known
// person" flow (invite-channel-member, invite-channel-share), since no
// client-facing RLS ever exposes the auth.users id<->email mapping and the
// admin API here has no email-filter query param, only pagination.
const USERS_PER_PAGE = 200;
const MAX_PAGES = 25; // 5000 users -- comfortably more than this app's user base

// deno-lint-ignore no-explicit-any
export async function findUserIdByEmail(supabaseAdmin: any, email: string): Promise<string | null> {
  const target = email.trim().toLowerCase();
  for (let page = 1; page <= MAX_PAGES; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: USERS_PER_PAGE });
    if (error || !data) return null;
    // deno-lint-ignore no-explicit-any
    const match = data.users.find((u: any) => u.email?.toLowerCase() === target);
    if (match) return match.id;
    if (data.users.length < USERS_PER_PAGE) return null; // last page, no match
  }
  return null;
}
