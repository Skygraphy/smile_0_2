# Edge function regression suite

Real, repeatable tests replacing the throwaway `.mjs` verification scripts
used earlier this session. There is no local Supabase/Postgres stack
available in this environment (Docker isn't running), so these tests run
against the **actual linked project** instead of a local sandbox --
every test creates its own throwaway auth user(s)/rows via the admin API
and tears them down in a `finally` block, so running the suite is safe
against real data. Do not hardcode secrets here -- everything comes from
environment variables.

## Running

```sh
export SUPABASE_URL="https://wxuipqaozvgzthlgnbgz.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."   # from: npx supabase projects api-keys --project-ref <ref>
export SUPABASE_ANON_KEY="..."           # same command, the "anon" row

deno test --allow-net --allow-env supabase/functions/_tests/
```

`helpers.ts`'s `FIXTURES` also assumes a couple of real, pre-existing rows
(a Space, two Channels, one real admin user) exist in the project --
override `TEST_ADMIN_EMAIL` / `TEST_OMA_SPACE_ID` /
`TEST_ENKELKINDER_CHANNEL_ID` / `TEST_STAMMTISCH_CHANNEL_ID` if the
project's seed data ever changes; the defaults match this project's
current "Oma" Space test data.

## What's covered vs. not

- `channel_join_requests.test.ts` -- Phase 6c: request → pending → list →
  approve (membership + `use_count`), and request → reject → re-request.
- `groups.test.ts` -- Phase 6b's `reconcile_channel_group_access` trigger:
  granting a channel to a group with existing members, removing a member
  revokes exactly what the group granted, a pre-existing direct membership
  is never duplicated/reattributed, and RLS blocks granting a channel the
  caller doesn't administer.
- `self_service_leave.test.ts` -- direct-membership self-leave, a
  group-derived row correctly refusing a direct self-leave, and leaving
  the group itself correctly cascading via the reconcile trigger.

Not yet covered (candidates for the next addition, not because they're
low-risk, just not ported yet): `delete-media` (delete/hide/unhide),
`assign-device-channel`'s `media_recipients` backfill, the
"Gerät ersetzen" pairing migration flow. Port the same pattern from this
session's transcript/scratchpad scripts if picking one of these up.
