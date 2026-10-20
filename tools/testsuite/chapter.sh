#!/usr/bin/env bash
# Records a chapter (source it after dev.sh): each step gets an
# instruction, the expected result, a screenshot, automatic checks and
# the list of every tappable element on its screen (for the coverage map).
# Every tap is logged with the screen it happened on.
# Output: out/<chapter>/steps.json, NN.png, taps.tsv -- read by build_site.sh.
OUT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out"
SCREEN=""
# One run per device at a time: a second run would tap into the first.
lock_device() {
  LOCK="$OUT_ROOT/.lock_${DEV//[:.]/_}"; mkdir -p "$OUT_ROOT"
  if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then echo "Auf $DEV läuft schon ein Lauf (PID $(cat "$LOCK"))." >&2; exit 4; fi
  echo $$ > "$LOCK"; trap 'rm -f "$LOCK"' EXIT
}
begin_chapter() { # id title intro
  CH_ID="$1"; CH_DIR="$OUT_ROOT/$1"; STEP_NO=0
  rm -rf "$CH_DIR"; mkdir -p "$CH_DIR"; : > "$CH_DIR/taps.tsv"
  # The app version and code state this run tests (CHANGELOG.md, git tag vX.Y.Z).
  local ver commit
  ver="$(sed -n 's/^version: \([^+]*\).*/\1/p' "$OUT_ROOT/../../../smile-app/pubspec.yaml")"
  commit="$(git -C "$OUT_ROOT/.." rev-parse --short HEAD)"
  node -e 'require("fs").writeFileSync(process.argv[1], JSON.stringify({id:process.argv[2],title:process.argv[3],intro:process.argv[4],appVersion:process.argv[5],commit:process.argv[6],steps:[]},null,1))' \
    "$(cygpath -w "$CH_DIR/steps.json")" "$1" "$2" "$3" "$ver" "$commit"
}
# A button the chapter needs is missing: the run is off track. Stop here
# (the steps so far stay recorded) instead of failing on every step after.
on_missing() { echo "ABBRUCH in Schritt $STEP_NO ($STEP_TITLE): $1 nicht gefunden" >&2; exit 3; }
# The page the app shows now (named as a user would: Anmeldung, Einstellungen ...).
screen() { SCREEN="$1"; }
# step "Titel" "Anleitung" "Erwartet" [Hauptweg|Abzweigung] [Gerät]
step() {
  STEP_NO=$((STEP_NO+1)); STEP_TITLE="$1"; STEP_DO="$2"; STEP_EXPECT="$3"
  STEP_KIND="${4:-Hauptweg}"; STEP_DEVICE="${5:-S26}"; STEP_CHECKS="[]"; SNAP_MASK=""; STEP_WHY=""
  echo "Schritt $STEP_NO: $1"
}
# explain "Was dabei passiert": what happens behind the screen, in plain words.
explain() { STEP_WHY="$1"; }
# check "Beschreibung" command... : records whether the command succeeds.
check() {
  local desc="$1"; shift
  local ok=false; "$@" >/dev/null 2>&1 && ok=true
  STEP_CHECKS="$(node -e 'const c=JSON.parse(process.argv[1]);c.push({desc:process.argv[2],ok:process.argv[3]==="true"});console.log(JSON.stringify(c))' "$STEP_CHECKS" "$desc" "$ok")"
  $ok || echo "  PRÜFUNG FEHLGESCHLAGEN: $desc" >&2
}
# Blacks out an element (by resource-id) in this step's screenshot, e.g.
# the contact row of Android's share sheet: private data never gets in.
mask_id() { SNAP_MASK="$1"; }
# Called by tap_el/go_back: which element was used on which screen.
log_tap() { [ -n "${CH_DIR:-}" ] && printf '%s\t%s\n' "$SCREEN" "$1" >> "$CH_DIR/taps.tsv"; return 0; }
# Takes the screenshot, lists the screen's tappable elements, closes the step.
snap() {
  local name; name="$(printf '%02d' "$STEP_NO").png"
  sleep "${1:-1}"
  local xml; xml="$(ui)"
  shot "$CH_DIR/$name"
  if [ -n "$SNAP_MASK" ]; then
    local box; box="$(echo "$xml" | node -e '
      const x=require("fs").readFileSync(0,"utf8"),id=process.argv[1];
      for (const m of x.matchAll(/<node [^>]*>/g)) { const n=m[0];
        if ((n.match(/resource-id="([^"]*)"/)||[])[1]===id) { const b=n.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/); console.log(b.slice(1).join(",")); break; } }' "$SNAP_MASK")"
    [ -n "$box" ] && powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing
      \$p='$(cygpath -w "$CH_DIR/$name")'; \$i=[System.Drawing.Image]::FromFile(\$p); \$b=New-Object System.Drawing.Bitmap \$i; \$i.Dispose()
      \$g=[System.Drawing.Graphics]::FromImage(\$b); \$r='$box'.Split(','); \$g.FillRectangle([System.Drawing.Brushes]::Black,[int]\$r[0],[int]\$r[1],[int]\$r[2]-[int]\$r[0],[int]\$r[3]-[int]\$r[1])
      \$b.Save(\$p); \$g.Dispose(); \$b.Dispose()"
  fi
  echo "$xml" | node -e '
    const fs=require("fs"),x=fs.readFileSync(0,"utf8"),[f,pkg,no,title,doIt,expect,kind,device,image,checks,scr,why]=process.argv.slice(1);
    const els=[];
    for (const m of x.matchAll(/<node [^>]*>/g)) { const n=m[0];
      if ((n.match(/ package="([^"]*)"/)||[])[1]!==pkg || !/ clickable="true"/.test(n)) continue;
      const get=a=>((n.match(new RegExp(" "+a+"=\"([^\"]*)\""))||[])[1]||"").replace(/&#10;/g," · ").replace(/&amp;/g,"&").trim();
      let l=get("content-desc")||get("text");
      if (/EditText/.test(get("class"))) l="Eingabefeld"+(get("hint")?": "+get("hint"):"");
      if (/^[0-9 ·]+$/.test(l)) l="Code-Kästchen";
      if (l && !els.includes(l)) els.push(l);
    }
    const j=JSON.parse(fs.readFileSync(f)); const nr=+no; j.steps=j.steps.filter(s=>s.no!==nr);
    j.steps.push({no:nr,title,do:doIt,expect,kind,device,image,checks:JSON.parse(checks),screen:scr,elements:els,why});
    j.steps.sort((a,b)=>a.no-b.no); fs.writeFileSync(f,JSON.stringify(j,null,1));' \
    "$(cygpath -w "$CH_DIR/steps.json")" "$TEST_PKG" "$STEP_NO" "$STEP_TITLE" "$STEP_DO" "$STEP_EXPECT" "$STEP_KIND" "$STEP_DEVICE" "$name" "$STEP_CHECKS" "$SCREEN" "$STEP_WHY"
}
# SQL against the testsuite project; prints the first value of the first row.
sql_value() {
  local f; f="$(mktemp --suffix=.sql)"; echo "$1" > "$f"
  npx supabase db query --linked --project-ref "$SMILE_TEST_PROJECT_REF" -f "$(cygpath -w "$f")" -o json 2>/dev/null \
    | node -e 'let s=require("fs").readFileSync(0,"utf8");s=s.slice(s.indexOf("{"));const j=JSON.parse(s);const r=(j.rows||j)[0];console.log(r?Object.values(r)[0]:"")'
  rm -f "$f"
}
# check helper: sql_is "<sql>" "<expected first value>"
sql_is() { [ "$(sql_value "$1")" = "$2" ]; }
# The colour at x,y on the screen right now is close to #rrggbb (each
# channel within 40): e.g. the background of a portrait, which tells the
# portraits apart.
screen_color_near() {
  local f; f="$(mktemp --suffix=.png)"; shot "$f"
  local rgb; rgb="$(powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; \$b=New-Object System.Drawing.Bitmap '$(cygpath -w "$f")'; \$c=\$b.GetPixel($1,$2); '{0} {1} {2}' -f \$c.R,\$c.G,\$c.B; \$b.Dispose()")"
  rm -f "$f"
  node -e 'const [r,g,b]=process.argv[1].trim().split(/\s+/).map(Number),h=process.argv[2];const t=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));process.exit([r,g,b].every((v,i)=>Math.abs(v-t[i])<=40)?0:1)' "$rgb" "$3"
}
