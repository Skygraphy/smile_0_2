#!/usr/bin/env bash
# Prepares the tutorial web app: site/index.html + every recorded chapter
# (out/chNN, screenshots shrunk to JPEG) + findings.json -> out/site.
set -euo pipefail
cd "$(dirname "$0")"
SITE=out/site
rm -rf "$SITE"; mkdir -p "$SITE/data"
cp site/index.html "$SITE/"
TITLES='{"ch01":"Erster Start"}'
chapters=()
for dir in out/ch[0-9][0-9]; do
  [ -f "$dir/steps.json" ] || continue
  id="$(basename "$dir")"; chapters+=("$id"); mkdir -p "$SITE/$id"
  powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing
    \$enc=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|?{\$_.MimeType -eq 'image/jpeg'}
    \$p=New-Object System.Drawing.Imaging.EncoderParameters 1
    \$p.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,[long]82)
    Get-ChildItem '$(cygpath -w "$dir")' -Filter *.png | % {
      \$img=[System.Drawing.Image]::FromFile(\$_.FullName); \$w=480; \$h=[int](\$img.Height*\$w/\$img.Width)
      \$bmp=New-Object System.Drawing.Bitmap \$w,\$h; \$g=[System.Drawing.Graphics]::FromImage(\$bmp)
      \$g.InterpolationMode='HighQualityBicubic'; \$g.DrawImage(\$img,0,0,\$w,\$h)
      \$bmp.Save((Join-Path '$(cygpath -w "$SITE/$id")' (\$_.BaseName+'.jpg')),\$enc,\$p); \$g.Dispose(); \$bmp.Dispose(); \$img.Dispose() }"
  node -e '
    const fs=require("fs"),[src,dst,no,ran]=process.argv.slice(1);const j=JSON.parse(fs.readFileSync(src));
    j.no=+no; j.ranAt=ran; fs.writeFileSync(dst,JSON.stringify(j));' \
    "$(cygpath -w "$dir/steps.json")" "$(cygpath -w "$SITE/$id/steps.json")" "${id#ch}" "$(date -r "$dir/steps.json" '+%d.%m.%Y %H:%M')"
done
node -e '
  const fs=require("fs"),[out,findings,...ids]=process.argv.slice(1);
  const chapters=ids.map(id=>{const j=JSON.parse(fs.readFileSync(out+"/"+id+"/steps.json"));return {id,no:j.no,title:j.title,steps:j.steps.length};});
  fs.writeFileSync(out+"/data/index.json",JSON.stringify({chapters,findings:JSON.parse(fs.readFileSync(findings))}));' \
  "$(cygpath -w "$SITE")" "$(cygpath -w findings.json)" "${chapters[@]}"
echo "$SITE: ${chapters[*]}"
