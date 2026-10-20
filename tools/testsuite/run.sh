#!/usr/bin/env bash
# Runs a chapter inside the test app (integration_test, no flutter drive):
#   DEV_S26=192.168.0.107:40549 ./run.sh ch01
# 1. builds the test app with the chapter, only when code changed,
# 2. installs it, only when the build changed,
# 3. fresh app data, test pictures in place, starts the app: the chapter
#    runs by itself and writes screenshots + steps.json on the phone,
# 4. waits for its done-signal and fetches everything into out/<chapter>.
# TESTSUITE project only.
set -euo pipefail
cd "$(dirname "$0")"
CH="${1:?Kapitel, z.B. ch01}"
DEV="${DEV_S26:?DEV_S26 setzen, z.B. 192.168.0.107:40549}"
source ./env.sh; source ./dev.sh
VER="$(sed -n 's/^version: \([^+]*\).*/\1/p' ../../smile-app/pubspec.yaml)"
OUT="$PWD/out/$CH"; rm -rf "$OUT"; mkdir -p "$OUT"
APK="build/app/outputs/flutter-apk/app-debug.apk"
REMOTE="/sdcard/Android/data/$TEST_PKG/files/testsuite_out/$CH"
cd ../../smile-app
t0=$(date +%s)
if [ ! -f "$APK" ] || [ "$(cat build/.testsuite_target 2>/dev/null)" != "$CH" ] \
   || [ -n "$(find lib integration_test ../packages/smile_design_system/lib pubspec.yaml -newer "$APK" -type f | head -1)" ]; then
  KEY="$(npx supabase projects api-keys --project-ref "$SMILE_TEST_PROJECT_REF" -o json 2>/dev/null | node -e "const k=JSON.parse(require('fs').readFileSync(0));console.log(k.find(x=>x.type==='publishable').api_key)")"
  flutter build apk --debug --target-platform android-arm64 -t "integration_test/${CH}_test.dart" \
    --dart-define=SMILE_TEST=true --dart-define=SMILE_APP_VERSION="$VER" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY" \
    --dart-define=SMILE_TEST_SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY" > "$OUT/build.log" 2>&1 || { tail -20 "$OUT/build.log"; exit 1; }
  echo "$CH" > build/.testsuite_target
fi
t1=$(date +%s)
SUM="$(md5sum "$APK" | cut -c1-32)"
MARK="build/.installed_${DEV//[:.]/_}"
if [ "$(cat "$MARK" 2>/dev/null)" != "$SUM" ]; then
  a install -r "$(cygpath -w "$APK")" >/dev/null && echo "$SUM" > "$MARK"
fi
clear_app; push_fixtures; demo_mode
t2=$(date +%s)
a logcat -c; a shell am start -n "$TEST_PKG/com.smile.smile_app.MainActivity" >/dev/null
for _ in $(seq 1 600); do
  a shell "[ -f $REMOTE/done.done ]" 2>/dev/null && break
  sleep 0.5
done
t3=$(date +%s)
a pull "$REMOTE/." "$(cygpath -w "$OUT")" >/dev/null
a logcat -d -s flutter > "$OUT/run.log" 2>/dev/null || true
[ -f "$OUT/failed.txt" ] && echo "ABGEBROCHEN: $(cat "$OUT/failed.txt")"
grep -h "PRÜFUNG FEHLGESCHLAGEN" "$OUT/run.log" | sed 's/^.*flutter *: *//' | sort -u || true
echo "Bauen: $((t1-t0)) s, Vorbereiten: $((t2-t1)) s, Kapitel: $((t3-t2)) s, Schritte: $(ls "$OUT"/*.png 2>/dev/null | wc -l)"
