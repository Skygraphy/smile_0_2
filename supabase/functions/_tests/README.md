# Edge function regression suite

Real, repeatable tests against a real Supabase project. They run against
their **own project, `smile_0_2_testsuite`** (ref `ohcrvjvhglrxxrkyrnhr`) --
never against the live one (`wxuipqaozvgzthlgnbgz`), where real families'
data lives. `helpers.ts` refuses to start against the live project unless
`SMILE_ALLOW_LIVE_TESTS=1` is set.

Every test creates its own throwaway users (`…@example.com`) and rows and
removes them in a `finally`. `deleteUser` fails loudly if the Auth API
refuses -- it used to ignore the answer, which hid a real bug
(migrations/0051) while test users piled up.

## Running

```sh
supabase/functions/_tests/run.sh                      # whole suite
supabase/functions/_tests/run.sh supabase/functions/_tests/architecture_fixes.test.ts
```

`run.sh` fetches the testsuite project's API keys through the Supabase CLI
(`npx supabase login` once); nothing secret lives in the repo.

## Keeping the testsuite project in step with live

Schema and functions must match what's deployed live, or the tests prove
nothing. After a change:

```sh
# migrations -- the DB password is in the Supabase dashboard / password manager
npx supabase db push --db-url "postgresql://postgres.ohcrvjvhglrxxrkyrnhr:<db-password>@aws-1-eu-west-1.pooler.supabase.com:5432/postgres"

# functions -- verify_jwt per function comes from supabase/config.toml
npx supabase functions deploy <name> --project-ref ohcrvjvhglrxxrkyrnhr
```

One-time setup the project already has (only needed again for a fresh
project): secrets `SYNC_FANOUT_SECRET` and `DEVICE_JWT_SECRET`
(`npx supabase secrets set --project-ref …`), and the Vault entries
`sync_fanout_url` / `sync_fanout_secret` (see migrations/0041_fcm_sync.sql).
No FCM credentials on purpose: test users have no devices, and every push
helper is best-effort.

## What's covered

- `architecture_reset.test.ts` -- the core model: channel creation, member
  invites, view-only shares, Frame pairing and assignment.
- `walkthrough_sept27.test.ts` -- fixes from the 2026-09-27 walkthrough:
  share revoke clears Frames, Administrator protected from co-owners,
  co-owners may delete photos, delete = trash/restore/Frame pause.
- `architecture_fixes.test.ts` -- the 2026-09-29 architecture review:
  owner ends a share, single-source authorization, a Frame only gets what
  its household sees, account deletion + co-owner handover.

Not yet covered: the real upload pipeline end-to-end (create-upload → real
bytes → complete-upload); refresh-frame-token's rotation; the outbox retry
(verified manually: a 404 call was retried after a minute).
