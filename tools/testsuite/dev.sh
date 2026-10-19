#!/usr/bin/env bash
# Device helpers for the test runs (source it). DEV must be set to the
# adb serial, e.g. DEV=192.168.0.107:36387. Only ever touches the test app.
export MSYS_NO_PATHCONV=1
ADB="${ADB:-/c/Users/ernst/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
TEST_PKG=com.smile.smile_app.test
a() { "$ADB" -s "$DEV" "$@"; }
ui() { a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; a shell cat /sdcard/ui.xml; }
# Center of the first element whose text, content-desc or hint starts with
# $1 (or "class:android.widget.EditText" for the first of a class).
find_el() {
  ui | node -e '
    const x=require("fs").readFileSync(0,"utf8"), w=process.argv[1];
    for (const m of x.matchAll(/<node [^>]*>/g)) {
      const n=m[0], c=(n.match(/ class="([^"]*)"/)||[])[1]||"", h=(n.match(/ hint="([^"]*)"/)||[])[1]||"", t=(n.match(/ text="([^"]*)"/)||[])[1]||"", d=(n.match(/content-desc="([^"]*)"/)||[])[1]||"";
      if (t.startsWith(w)||d.startsWith(w)||h.startsWith(w)||(w.startsWith("class:")&&c===w.slice(6))) { const b=n.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/); console.log(((+b[1]+ +b[3])>>1)+" "+((+b[2]+ +b[4])>>1)); process.exit(0); }
    } process.exit(1);' "$1"
}
# Waits up to $2 seconds (default 15) for an element, then taps it.
tap_el() {
  local xy; for _ in $(seq 1 "${2:-15}"); do xy="$(find_el "$1")" && { a shell input tap $xy; return 0; }; sleep 1; done
  echo "Nicht gefunden: $1" >&2; return 1
}
wait_el() { for _ in $(seq 1 "${2:-15}"); do find_el "$1" >/dev/null && return 0; sleep 1; done; echo "Nicht gefunden: $1" >&2; return 1; }
type_text() { a shell input text "$(echo "$1" | sed 's/ /%s/g')"; }
shot() { a exec-out screencap -p > "$1"; }
start_app() { a shell am start -n $TEST_PKG/com.smile.smile_app.MainActivity >/dev/null; }
# Fresh test app, notifications already allowed (no system dialog in runs).
clear_app() { a shell pm clear $TEST_PKG >/dev/null; a shell pm grant $TEST_PKG android.permission.POST_NOTIFICATIONS; }
# Signs a test person in on a freshly cleared test app.
login() {
  local email="$1"
  start_app
  tap_el "class:android.widget.EditText" 20; type_text "$email"
  tap_el "Code anfordern"
  sleep 2
  local code; code="$(deno run --node-modules-dir=none --allow-net --allow-env "$(dirname "${BASH_SOURCE[0]}")/otp.ts" "$email")"
  type_text "$code"
}
