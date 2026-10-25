#!/usr/bin/env bash
# Runs a chapter inside the test app (integration_test, no flutter drive):
#   DEV_S26=192.168.0.107:40549 ./run.sh ch01
# 1. builds the test app with the chapter, only when code changed,
# 2. installs it, only when the build changed,
# 3. fresh app data, test pictures in place, starts the app: the chapter
#    runs by itself and writes screenshots + steps.json on the phone,
# 4. waits for its done-signal and fetches everything into out/<chapter>.
# A chapter with a Frame part (integration_test/<chapter>f_test.dart, from
# chapter 6 on) runs that part at the same time on DEV_X200; merge.js then
# puts both into out/<chapter>, step by step in the order they happened.
# TESTSUITE project only.
set -euo pipefail
cd "$(dirname "$0")"
CH="${1:?Kapitel, z.B. ch01}"
DEV_PHONE="${DEV_S26:?DEV_S26 setzen, z.B. 192.168.0.107:40549}"
source ./env.sh; source ./dev.sh
VER="$(sed -n 's/^version: \([^+]*\).*/\1/p' ../../smile-app/pubspec.yaml)"
HERE="$PWD"
FRAME_PART=""
[ -f "../../smile-app/integration_test/${CH}f_test.dart" ] && FRAME_PART="${CH}f"
if [ -n "$FRAME_PART" ]; then DEV_FRAME="${DEV_X200:?DEV_X200 setzen: dieses Kapitel hat einen Frame-Teil}"; fi

cd ../../smile-app
mkdir -p build/testsuite
t0=$(date +%s)
KEY=""
# Builds integration_test/<target>_test.dart into build/testsuite/<target>.apk
# when anything it depends on is newer than that apk.
build_target() {
  local target="$1" out="$HERE/out/$1" apk="build/testsuite/$1.apk"
  rm -rf "$out"; mkdir -p "$out"
  if [ ! -f "$apk" ] || [ -n "$(find lib integration_test ../packages/smile_design_system/lib pubspec.yaml -newer "$apk" -type f | head -1)" ]; then
    [ -n "$KEY" ] || KEY="$(npx supabase projects api-keys --project-ref "$SMILE_TEST_PROJECT_REF" -o json 2>/dev/null | node -e "const k=JSON.parse(require('fs').readFileSync(0));console.log(k.find(x=>x.type==='publishable').api_key)")"
    flutter build apk --debug --target-platform android-arm64 -t "integration_test/${target}_test.dart" \
      --dart-define=SMILE_TEST=true --dart-define=SMILE_APP_VERSION="$VER" \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY" \
      --dart-define=SMILE_TEST_SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY" > "$out/build.log" 2>&1 || { tail -20 "$out/build.log"; exit 1; }
    cp build/app/outputs/flutter-apk/app-debug.apk "$apk"
  fi
}
build_target "$CH"
[ -n "$FRAME_PART" ] && build_target "$FRAME_PART"
t1=$(date +%s)

# Installs (if changed) and prepares a device, then starts the app on it.
prepare() {
  local target="$1"; DEV="$2"
  local apk="build/testsuite/$target.apk" sum mark
  sum="$(md5sum "$apk" | cut -c1-32)"; mark="build/.installed_${DEV//[:.]/_}"
  if [ "$(cat "$mark" 2>/dev/null)" != "$sum" ]; then
    a install -r "$(cygpath -w "$apk")" >/dev/null && echo "$sum" > "$mark"
  fi
  clear_app; push_fixtures; demo_mode
}
launch() { DEV="$1"; a logcat -c; a shell am start -n "$TEST_PKG/com.smile.smile_app.MainActivity" >/dev/null; }
prepare "$CH" "$DEV_PHONE"
[ -n "$FRAME_PART" ] && prepare "$FRAME_PART" "$DEV_FRAME"
t2=$(date +%s)
[ -n "$FRAME_PART" ] && launch "$DEV_FRAME"
launch "$DEV_PHONE"

# Waits for a part's done-signal, then fetches its results.
fetch() {
  local target="$1"; DEV="$2"
  local remote="/sdcard/Android/data/$TEST_PKG/files/testsuite_out/$target" out="$HERE/out/$target"
  for _ in $(seq 1 1200); do
    a shell "[ -f $remote/done.done ]" 2>/dev/null && break
    sleep 0.5
  done
  a pull "$remote/." "$(cygpath -w "$out")" >/dev/null
  a logcat -d -s flutter > "$out/run.log" 2>/dev/null || true
}
fetch "$CH" "$DEV_PHONE"
if [ -n "$FRAME_PART" ]; then
  FRAME_DONE="/sdcard/Android/data/$TEST_PKG/files/testsuite_out/$FRAME_PART/done.done"
  if [ -f "$HERE/out/$CH/failed.txt" ] && ! (DEV="$DEV_FRAME"; a shell "[ -f $FRAME_DONE ]" 2>/dev/null); then
    # The phone part stopped and the Frame part is not done: it would only
    # wait for the phone.
    DEV="$DEV_FRAME"; a shell am force-stop "$TEST_PKG"
    a logcat -d -s flutter > "$HERE/out/$FRAME_PART/run.log" 2>/dev/null || true
    echo "nicht gelaufen, der Teil am Handy ist abgebrochen" > "$HERE/out/$FRAME_PART/failed.txt"
    echo "{\"steps\":[]}" > "$HERE/out/$FRAME_PART/steps.json"
  else
    fetch "$FRAME_PART" "$DEV_FRAME"
  fi
fi
t3=$(date +%s)
cd "$HERE"
report() {
  local out="out/$1"
  [ -f "$out/failed.txt" ] && echo "ABGEBROCHEN ($1): $(cat "$out/failed.txt")"
  grep -q "Some tests failed" "$out/run.log" && { echo "TEST-RAHMEN MELDET FEHLER ($1):"; grep -h -A3 "EXCEPTION CAUGHT" "$out/run.log" | sed "s/^.*flutter *: *//" | grep -v "^═" | head -8; }
  grep -h "PRÜFUNG FEHLGESCHLAGEN" "$out/run.log" | sed 's/^.*flutter *: *//' | sort -u || true
}
report "$CH"
if [ -n "$FRAME_PART" ]; then
  report "$FRAME_PART"
  node merge.js "$(cygpath -w out/$CH)" "$(cygpath -w out/$FRAME_PART)"
fi
echo "Bauen: $((t1-t0)) s, Vorbereiten: $((t2-t1)) s, Kapitel: $((t3-t2)) s, Schritte: $(ls out/"$CH"/*.png 2>/dev/null | wc -l)"
