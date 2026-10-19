#!/usr/bin/env bash
# Loads the TESTSUITE project's URL and keys into the environment
# (source it). Never the live project: refuses wxuipqaozvgzthlgnbgz.
# Keys come from the Supabase CLI (`npx supabase login` once); nothing
# secret is stored in the repo.
REF="${SMILE_TEST_PROJECT_REF:-ohcrvjvhglrxxrkyrnhr}"
if [ "$REF" = "wxuipqaozvgzthlgnbgz" ]; then
  echo "Refusing: that is the LIVE project." >&2
  return 1 2>/dev/null || exit 1
fi
KEYS="$(npx supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null)"
key() { echo "$KEYS" | node -e "const k=JSON.parse(require('fs').readFileSync(0));console.log(k.find(x=>x.name==='$1').api_key)"; }
export SMILE_TEST_PROJECT_REF="$REF"
export SUPABASE_URL="https://${REF}.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="$(key service_role)"
export SUPABASE_ANON_KEY="$(key anon)"
