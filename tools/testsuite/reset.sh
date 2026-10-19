#!/usr/bin/env bash
# Sets the TESTSUITE project back to zero: no users, spaces, albums,
# frames, photos or videos. Never touches the live project (env.sh refuses
# it, and reset.sql aborts as soon as a user with a real address exists).
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
deno run --node-modules-dir=none --allow-net --allow-env reset_storage.ts
out="$(npx supabase db query --linked --project-ref "$SMILE_TEST_PROJECT_REF" -f "$(cygpath -w "$PWD/reset.sql")" -o table 2>&1 || true)"
if echo "$out" | grep -qiE "error|abbruch|failed"; then
  echo "$out" | grep -iE "error|abbruch|failed" >&2
  exit 1
fi
echo "Testprojekt $SMILE_TEST_PROJECT_REF ist auf null."
