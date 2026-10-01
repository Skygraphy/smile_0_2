#!/usr/bin/env bash
# Runs the regression suite against the TESTSUITE project
# (smile_0_2_testsuite) -- never the live one. Fetches the project's API keys
# through the Supabase CLI (needs `npx supabase login` once); no secret is
# stored in the repo. Extra arguments go to `deno test`, e.g. a single file:
#   supabase/functions/_tests/run.sh supabase/functions/_tests/architecture_fixes.test.ts
set -euo pipefail

REF="${SMILE_TEST_PROJECT_REF:-ohcrvjvhglrxxrkyrnhr}"
cd "$(dirname "$0")/../../.."

KEYS="$(npx supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null)"
key() { echo "$KEYS" | node -e "const k=JSON.parse(require('fs').readFileSync(0));console.log(k.find(x=>x.name==='$1').api_key)"; }

export SUPABASE_URL="https://${REF}.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="$(key service_role)"
export SUPABASE_ANON_KEY="$(key anon)"

if [ "$#" -gt 0 ]; then
  deno test --node-modules-dir=none --allow-net --allow-env "$@"
else
  deno test --node-modules-dir=none --allow-net --allow-env supabase/functions/_tests/
fi
