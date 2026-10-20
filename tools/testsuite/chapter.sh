#!/usr/bin/env bash
# Records a chapter (source it after dev.sh): each step gets an
# instruction, the expected result, a screenshot and automatic checks.
# Output: out/<chapter>/steps.json + NN.png, read by publish.ts.
OUT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out"
begin_chapter() { # id title intro
  CH_ID="$1"; CH_DIR="$OUT_ROOT/$1"; STEP_NO=0
  rm -rf "$CH_DIR"; mkdir -p "$CH_DIR"
  node -e 'require("fs").writeFileSync(process.argv[1], JSON.stringify({id:process.argv[2],title:process.argv[3],intro:process.argv[4],steps:[]},null,1))' \
    "$(cygpath -w "$CH_DIR/steps.json")" "$1" "$2" "$3"
}
# step "Titel" "Anleitung (was man tut)" "Erwartet (was man sieht)" [device-label]
step() {
  STEP_NO=$((STEP_NO+1)); STEP_TITLE="$1"; STEP_DO="$2"; STEP_EXPECT="$3"; STEP_DEVICE="${4:-S26}"; STEP_CHECKS="[]"
  echo "Schritt $STEP_NO: $1"
}
# check "Beschreibung" command... : records whether the command succeeds.
check() {
  local desc="$1"; shift
  local ok=false; "$@" >/dev/null 2>&1 && ok=true
  STEP_CHECKS="$(node -e 'const c=JSON.parse(process.argv[1]);c.push({desc:process.argv[2],ok:process.argv[3]==="true"});console.log(JSON.stringify(c))' "$STEP_CHECKS" "$desc" "$ok")"
  $ok || echo "  PRÜFUNG FEHLGESCHLAGEN: $desc" >&2
}
# Takes the screenshot and closes the step.
snap() {
  local name; name="$(printf '%02d' "$STEP_NO").png"
  sleep "${1:-1}"
  shot "$CH_DIR/$name"
  node -e '
    const fs=require("fs"),f=process.argv[1],j=JSON.parse(fs.readFileSync(f));
    const no=+process.argv[2]; j.steps=j.steps.filter(s=>s.no!==no);
    j.steps.push({no,title:process.argv[3],do:process.argv[4],expect:process.argv[5],device:process.argv[6],image:process.argv[7],checks:JSON.parse(process.argv[8])});
    j.steps.sort((x,y)=>x.no-y.no); fs.writeFileSync(f,JSON.stringify(j,null,1));' \
    "$(cygpath -w "$CH_DIR/steps.json")" "$STEP_NO" "$STEP_TITLE" "$STEP_DO" "$STEP_EXPECT" "$STEP_DEVICE" "$name" "$STEP_CHECKS"
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
