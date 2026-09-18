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

`helpers.ts`'s `FIXTURES` only names two real, pre-existing project
accounts (`TEST_ADMIN_EMAIL` / `TEST_ERNST_EMAIL`) -- override if those
ever change. Everything else (Spaces, Channels, Frames) is created and
torn down per-test: the architecture reset
(migrations/0031_architecture_reset.sql) wiped every row, so there are no
more fixed Space/Channel ids to point at.

## What's covered vs. not

- `architecture_reset.test.ts` -- the Phase 2 (Edge Functions) suite for
  the User/Space/Channel/Frame model: channel creation auto-joins its SCO
  and hides the channel from a stranger; a channel-membership invite is
  invisible to the invitee until accepted (`list-my-invites` resolves the
  channel name for them) and grants posting rights once accepted; a
  channel-share invite grants a linked Space's owner view access but a
  verified hard `403` on any write, and is unilaterally revocable; a Frame
  created via `create-frame` can be claimed via `claim-frame-pairing`, and
  `assign-frame-channel` backfills `media_recipients` for a channel's
  already-`ready` photos so `get-media-batch`'s very first poll sees them.

Not yet covered (candidates for the next addition, not because they're
low-risk, just not ported yet): the real upload pipeline end-to-end
(`create-upload` → real bytes PUT to the signed URL → `complete-upload` →
`fanOutToFrames`) -- `architecture_reset.test.ts` seeds an already-`ready`
media_items row directly instead, to test the assignment/backfill/poll
path without needing real storage bytes; `delete-media` (delete/hide/
unhide) against the new schema; `refresh-frame-token`'s rotation.
