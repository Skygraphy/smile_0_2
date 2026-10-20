#!/usr/bin/env bash
# Device helpers for the test runs (source it). DEV must be set to the
# adb serial, e.g. DEV=192.168.0.107:36387. Only ever touches the test app.
export MSYS_NO_PATHCONV=1
ADB="${ADB:-/c/Users/ernst/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
TEST_PKG=com.smile.smile_app.test
TESTSUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
a() { "$ADB" -s "$DEV" "$@"; }
ui() { a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; a shell cat /sdcard/ui.xml; }
# Center of the first element whose text, content-desc or hint starts with
# $1 (or "class:android.widget.EditText" for the first of a class, or
# "~text" for an element that merely contains the text).
find_el() {
  ui | node -e '
    const x=require("fs").readFileSync(0,"utf8"), w=process.argv[1], last=process.env.FIND_LAST==="1"; let hit=null;
    for (const m of x.matchAll(/<node [^>]*>/g)) {
      const n=m[0], c=(n.match(/ class="([^"]*)"/)||[])[1]||"", h=(n.match(/ hint="([^"]*)"/)||[])[1]||"",
        t=(n.match(/ text="([^"]*)"/)||[])[1]||"", d=(n.match(/content-desc="([^"]*)"/)||[])[1]||"";
      const inc=w.startsWith("~")?w.slice(1):null;
      if (inc ? (t.includes(inc)||d.includes(inc)) : t.startsWith(w)||d.startsWith(w)||h.startsWith(w)||(w.startsWith("class:")&&c===w.slice(6))) {
        const b=n.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
        hit=((+b[1]+ +b[3])>>1)+" "+((+b[2]+ +b[4])>>1); if (!last) break;
      }
    } if (hit) { console.log(hit); process.exit(0); } process.exit(1);' "$1"
}
# Waits up to $2 seconds (default 15) for an element, then taps it.
tap_el() {
  local xy; for _ in $(seq 1 "${2:-15}"); do xy="$(find_el "$1")" && { a shell input tap $xy; type log_tap >/dev/null 2>&1 && log_tap "$1"; return 0; }; sleep 1; done
  echo "Nicht gefunden: $1" >&2; type on_missing >/dev/null 2>&1 && on_missing "$1"; return 1
}
# A tap on a spot without a name (logged under the given label).
tap_at() { a shell input tap "$1" "$2"; type log_tap >/dev/null 2>&1 && log_tap "$3"; return 0; }
# Like tap_el, but the last match (a dialog button over a same-named row).
tap_last() { FIND_LAST=1 tap_el "$@"; }
wait_el() { for _ in $(seq 1 "${2:-15}"); do find_el "$1" >/dev/null && return 0; sleep 1; done; echo "Nicht gefunden: $1" >&2; return 1; }
gone_el() { for _ in $(seq 1 "${2:-15}"); do find_el "$1" >/dev/null || return 0; sleep 1; done; return 1; }
type_text() { a shell input text "$(echo "$1" | sed 's/ /%s/g')"; }
# The system back gesture, logged like a tap on the page's Zurück arrow.
go_back() { type log_tap >/dev/null 2>&1 && log_tap "Zurück"; a shell input keyevent 4; }
hide_keyboard() { a shell input keyevent 111; }
shot() { a exec-out screencap -p > "$1"; }
start_app() { a shell am start -n $TEST_PKG/com.smile.smile_app.MainActivity >/dev/null 2>&1; }
# Clean status bar for the screenshots: no private notification icons.
demo_mode() {
  a shell settings put global sysui_demo_allowed 1
  a shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  a shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
}
# Fresh test app, notifications already allowed (no system dialog in runs).
clear_app() {
  a shell pm clear $TEST_PKG >/dev/null
  a shell pm grant $TEST_PKG android.permission.POST_NOTIFICATIONS
}
# Tips off for chapter runs (they have their own chapter): put into the
# fresh app's preferences before its first start (debug build: run-as).
tips_off() {
  a push "$(cygpath -w "$TESTSUITE_DIR/fixtures/prefs_tips_off.xml")" /data/local/tmp/smile_prefs.xml >/dev/null
  a shell chmod 644 /data/local/tmp/smile_prefs.xml
  a shell "run-as $TEST_PKG sh -c 'mkdir -p shared_prefs && cp /data/local/tmp/smile_prefs.xml shared_prefs/FlutterSharedPreferences.xml'"
}
# The 6-digit code the mail would have brought.
otp_for() { deno run --node-modules-dir=none --allow-net --allow-env "$(cygpath -w "$TESTSUITE_DIR/otp.ts")" "$1"; }
# Signs a test person in on a freshly cleared test app.
login() {
  local email="$1"
  start_app
  tap_el "class:android.widget.EditText" 20; type_text "$email"
  tap_el "Code anfordern"
  wait_el "Bestätigen" 10
  type_text "$(otp_for "$email")"
}
# The test pictures/videos (fixtures/media, from make_media.js) and the
# portraits (fixtures/profiles, make_portraits.js) into the test app's own folder; after
# clear_app, which empties it.
push_fixtures() {
  local dest=/sdcard/Android/data/$TEST_PKG/files/fixtures
  a shell mkdir -p $dest
  for d in media profiles; do
    [ -d "$TESTSUITE_DIR/fixtures/$d" ] && a push "$(cygpath -w "$TESTSUITE_DIR/fixtures/$d")" $dest/ >/dev/null
  done
  return 0
}
# Input fields by their label (what the field shows as its name, e.g.
# "Name", "E-Mail-Adresse", "https://"); "" = the only or topmost-in-a-dialog
# field (the last one in the screen tree). field_info prints "x y text".
field_info() {
  ui | node -e '
    const x=require("fs").readFileSync(0,"utf8"), w=process.argv[1]; let hit=null;
    for (const m of x.matchAll(/<node [^>]*>/g)) { const n=m[0];
      if (!/class="android.widget.EditText"/.test(n)) continue;
      const h=(n.match(/ hint="([^"]*)"/)||[])[1]||"", t=(n.match(/ text="([^"]*)"/)||[])[1]||"";
      if (w && !h.startsWith(w)) continue;
      const b=n.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
      hit=((+b[1]+ +b[3])>>1)+" "+((+b[2]+ +b[4])>>1)+" "+t.replace(/&amp;/g,"&");
    } if (hit) { console.log(hit); process.exit(0); } process.exit(1);' "$1"
}
# Clears the field, types the text and checks it arrived in exactly that
# field; stops the chapter if not (a wrong field would run it off track).
type_into() {
  local label="$1" text="$2" info x y
  for _ in $(seq 1 10); do info="$(field_info "$label")" && break; sleep 1; done
  [ -z "$info" ] && { echo "Eingabefeld nicht gefunden: ${label:-(einziges)}" >&2; type on_missing >/dev/null 2>&1 && on_missing "Eingabefeld ${label}"; return 1; }
  read -r x y _ <<< "$info"
  a shell input tap "$x" "$y"; type log_tap >/dev/null 2>&1 && log_tap "Eingabefeld${label:+: $label}"
  a shell input keyevent KEYCODE_MOVE_END; for _ in $(seq 1 40); do a shell input keyevent 67; done
  type_text "$text"; sleep 1
  info="$(field_info "$label")"
  case "${info#* * }" in
    *"$text"*) return 0 ;;
    *) echo "Text kam nicht im Feld ${label:-(einziges)} an: ${info#* * }" >&2; type on_missing >/dev/null 2>&1 && on_missing "Text im Feld ${label}"; return 1 ;;
  esac
}
