#!/usr/bin/env bash
# Testlab helpers for Claude (2026-10-17). Source it:  . tools/testlab/tl.sh
#   shot <s26|x200|p610> <name>   screenshot into run/shots/<name>.png
#   tap <device> <x> <y>          tap (device pixels)
#   type <device> <text>          type ASCII text (spaces allowed)
#   ui <device> <text>            centre "x y" of the first UI node whose
#                                 text or content-desc contains <text>
#   focus <device>                the window in front
export MSYS_NO_PATHCONV=1
ADB=/c/Users/ernst/AppData/Local/Android/Sdk/platform-tools/adb.exe
TL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -A DEV=([s26]=192.168.0.107:41201 [x200]=192.168.0.114:44345 [p610]=192.168.0.115:33879)

shot() { "$ADB" -s "${DEV[$1]}" exec-out screencap -p > "$TL/run/shots/$2.png"; }
tap() { "$ADB" -s "${DEV[$1]}" shell input tap "$2" "$3"; }
swipe() { "$ADB" -s "${DEV[$1]}" shell input swipe "$2" "$3" "$4" "$5" "${6:-350}"; }
type() { local t="${2// /%s}"; "$ADB" -s "${DEV[$1]}" shell input text "$t"; }
key() { "$ADB" -s "${DEV[$1]}" shell input keyevent "$2"; }
focus() { "$ADB" -s "${DEV[$1]}" shell dumpsys window | grep -m1 mCurrentFocus; }
ui() {
  "$ADB" -s "${DEV[$1]}" shell uiautomator dump /sdcard/tl_ui.xml >/dev/null 2>&1
  "$ADB" -s "${DEV[$1]}" exec-out cat /sdcard/tl_ui.xml | tr '>' '\n' | grep -i -- "$2" | head -1 |
    grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | tr -c '0-9\n' ' ' |
    awk '{print int(($1+$3)/2), int(($2+$4)/2)}'
}
