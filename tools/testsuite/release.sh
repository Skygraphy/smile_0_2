#!/usr/bin/env bash
# A new version for testing: ./release.sh ["Kurzbeschreibung"]
#  - raises the last number of the app version (0.0.1 -> 0.0.2) and the
#    build number (smile-app/pubspec.yaml),
#  - every finding fixed since the last version gets this version
#    (findings.json) and goes into a new CHANGELOG.md section,
#  - commits and sets the git tag vX.Y.Z.
# The chapters are then run again; build_site.sh files them under the new
# version, the older tutorials stay readable.
set -euo pipefail
cd "$(dirname "$0")"
PUBSPEC=../../smile-app/pubspec.yaml
old="$(sed -n 's/^version: \(.*\)$/\1/p' "$PUBSPEC")"
name="${old%+*}"; build="${old#*+}"
IFS=. read -r major minor patch <<< "$name"
new="$major.$minor.$((patch + 1))"
sed -i "s/^version: .*/version: $new+$((build + 1))/" "$PUBSPEC"

node -e '
  const fs=require("fs"),[findings,changelog,ver,summary]=process.argv.slice(1);
  const f=JSON.parse(fs.readFileSync(findings,"utf8"));
  const fixed=f.filter(x=>x.status==="behoben"&&!x.version);
  for(const x of fixed) x.version=ver;
  fs.writeFileSync(findings,JSON.stringify(f,null,2));
  const day=new Date().toISOString().slice(0,10);
  const lines=["## "+ver+" ("+day+")",""];
  if(summary) lines.push(summary,"");
  if(fixed.length){lines.push("Behoben:","");for(const x of fixed)lines.push("- "+x.no+": "+x.title);lines.push("");}
  const log=fs.readFileSync(changelog,"utf8");const at=log.indexOf("\n## ");
  fs.writeFileSync(changelog,at<0?log+"\n"+lines.join("\n"):log.slice(0,at+1)+lines.join("\n")+"\n"+log.slice(at+1));
  console.log(fixed.length+" Funde in "+ver);' \
  "$(cygpath -w findings.json)" "$(cygpath -w ../../CHANGELOG.md)" "$new" "${1:-}"

git -C ../.. add CHANGELOG.md smile-app/pubspec.yaml tools/testsuite/findings.json
git -C ../.. commit -q -m "Version $new"
git -C ../.. tag -a "v$new" -m "Smile $new"
echo "Version $new (Build $((build + 1))), Tag v$new. Jetzt: build_app.sh, Kapitel laufen lassen, build_site.sh."
