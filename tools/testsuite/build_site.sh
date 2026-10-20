#!/usr/bin/env bash
# Prepares the tutorial web app in out/site:
#  - the chapters just recorded (out/chNN, screenshots shrunk to JPEG) go
#    into the archive of their app version (out/archive/<version>/chNN);
#  - every archived version is published under v/<version>/, so older
#    tutorials stay readable;
#  - data/index.json lists the versions (with their CHANGELOG section),
#    data/coverage.json is the coverage of the newest version.
set -euo pipefail
cd "$(dirname "$0")"
SITE=out/site
ARCHIVE=out/archive
APP_VERSION="$(sed -n 's/^version: \([^+]*\).*/\1/p' ../../smile-app/pubspec.yaml)"

for dir in out/ch[0-9][0-9]; do
  [ -f "$dir/steps.json" ] || continue
  id="$(basename "$dir")"
  ver="$(node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(j.appVersion||process.argv[2])' "$(cygpath -w "$dir/steps.json")" "$APP_VERSION")"
  dest="$ARCHIVE/$ver/$id"
  # Only what is newer than the archive copy is processed again.
  [ -f "$dest/steps.json" ] && [ "$dest/steps.json" -nt "$dir/steps.json" ] && continue
  rm -rf "$dest"; mkdir -p "$dest"
  powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing
    \$enc=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|?{\$_.MimeType -eq 'image/jpeg'}
    \$p=New-Object System.Drawing.Imaging.EncoderParameters 1
    \$p.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,[long]82)
    Get-ChildItem '$(cygpath -w "$dir")' -Filter *.png | % {
      \$img=[System.Drawing.Image]::FromFile(\$_.FullName); \$w=480; \$h=[int](\$img.Height*\$w/\$img.Width)
      \$bmp=New-Object System.Drawing.Bitmap \$w,\$h; \$g=[System.Drawing.Graphics]::FromImage(\$bmp)
      \$g.InterpolationMode='HighQualityBicubic'; \$g.DrawImage(\$img,0,0,\$w,\$h)
      \$bmp.Save((Join-Path '$(cygpath -w "$dest")' (\$_.BaseName+'.jpg')),\$enc,\$p); \$g.Dispose(); \$bmp.Dispose(); \$img.Dispose() }"
  node -e '
    const fs=require("fs"),[src,dst,no,ran,ver]=process.argv.slice(1);const j=JSON.parse(fs.readFileSync(src));
    j.no=+no; j.ranAt=ran; j.appVersion=j.appVersion||ver; fs.writeFileSync(dst,JSON.stringify(j));' \
    "$(cygpath -w "$dir/steps.json")" "$(cygpath -w "$dest/steps.json")" "${id#ch}" "$(date -r "$dir/steps.json" '+%d.%m.%Y %H:%M')" "$ver"
done

rm -rf "$SITE"; mkdir -p "$SITE/data" "$SITE/v"
cp site/index.html "$SITE/"
cp -r "$ARCHIVE"/. "$SITE/v/"
node -e '
  const fs=require("fs"),path=require("path"),[site,findings,changelog]=process.argv.slice(1);
  const cmp=(a,b)=>{const x=a.split(".").map(Number),y=b.split(".").map(Number);for(let i=0;i<3;i++)if(x[i]!==y[i])return x[i]-y[i];return 0;};
  const log=fs.readFileSync(changelog,"utf8");
  const section=v=>{const m=log.split(/^## /m).find(s=>s.startsWith(v+" "));return m?m.split("\n").slice(1).join("\n").trim():"";};
  const versions=fs.readdirSync(path.join(site,"v")).sort(cmp).reverse().map(v=>{
    const chapters=fs.readdirSync(path.join(site,"v",v)).filter(d=>/^ch\d\d$/.test(d)).sort().map(id=>{
      const j=JSON.parse(fs.readFileSync(path.join(site,"v",v,id,"steps.json")));return {id,no:j.no,title:j.title,steps:j.steps.length,ranAt:j.ranAt};});
    const head=(log.match(new RegExp("^## "+v.replace(/\./g,"\\.")+" \\(([^)]*)\\)","m"))||[])[1]||"";
    return {version:v,date:head,changelog:section(v),chapters};});
  fs.writeFileSync(path.join(site,"data","index.json"),JSON.stringify({versions,findings:JSON.parse(fs.readFileSync(findings))}));' \
  "$(cygpath -w "$SITE")" "$(cygpath -w findings.json)" "$(cygpath -w ../../CHANGELOG.md)"
node coverage.js "$(cygpath -w out)" "$(cygpath -w "$SITE/data")"
echo "$SITE: $(ls "$SITE/v" | tr '\n' ' ')"
