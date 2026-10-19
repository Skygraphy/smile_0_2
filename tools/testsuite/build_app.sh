#!/usr/bin/env bash
# Builds "Smile Test" (com.smile.smile_app.test) against the TESTSUITE
# project: debug by default, `build_app.sh release` for a release build.
# The publishable key is public by design; it is fetched, not stored.
set -euo pipefail
MODE="${1:-debug}"
REF="${SMILE_TEST_PROJECT_REF:-ohcrvjvhglrxxrkyrnhr}"
[ "$REF" = "wxuipqaozvgzthlgnbgz" ] && { echo "Refusing: LIVE project." >&2; exit 1; }
KEY="$(npx supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null | node -e "const k=JSON.parse(require('fs').readFileSync(0));console.log(k.find(x=>x.type==='publishable').api_key)")"
cd "$(dirname "$0")/../../smile-app"
flutter build apk "--$MODE" \
  --dart-define=SMILE_TEST=true \
  --dart-define=SUPABASE_URL="https://$REF.supabase.co" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY"
cp "build/app/outputs/flutter-apk/app-$MODE.apk" "build/smile-test-$MODE.apk"
echo "build/smile-test-$MODE.apk"
