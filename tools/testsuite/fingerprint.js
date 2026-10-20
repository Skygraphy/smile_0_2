// Fingerprints of the steps of one recorded chapter, so a confirmation
// (Passt) only counts for what was actually seen:
//  - imgHash: a difference hash of the screenshot (status bar and the
//    navigation bar cut off, 17x16 grey pixels -> 256 bits), so the clock
//    or the battery don't count, a changed screen does;
//  - textHash: title, instruction and expected result;
//  - ctxHash: the state before and after the step (what the server holds
//    and the phone keeps): the same screen in another context is not the
//    same step.
//   node fingerprint.js <dir with NN.png> <steps.json to update>
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const { execFileSync } = require("child_process");
const ffmpeg = process.env.FFMPEG || require("ffmpeg-static");
const [dir, stepsFile] = process.argv.slice(2);

function imgHash(png) {
  const raw = execFileSync(ffmpeg, ["-loglevel", "error", "-i", png,
    "-vf", "crop=iw:ih-330:0:150,scale=17:16:flags=area,format=gray", "-f", "rawvideo", "-"]);
  let bits = "";
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) bits += raw[y * 17 + x] > raw[y * 17 + x + 1] ? "1" : "0";
  return bits.match(/.{4}/g).map(b => parseInt(b, 2).toString(16)).join("");
}

const j = JSON.parse(fs.readFileSync(stepsFile, "utf8"));
for (const s of j.steps) {
  const png = path.join(dir, s.image);
  if (fs.existsSync(png)) s.imgHash = imgHash(png);
  s.textHash = crypto.createHash("sha1").update([s.title, s.do, s.expect].join("\n")).digest("hex").slice(0, 16);
  // The context: the state before and after the step (server and phone).
  s.ctxHash = crypto.createHash("sha1").update(JSON.stringify([s.stateBefore ?? null, s.stateAfter ?? null])).digest("hex").slice(0, 16);
}
fs.writeFileSync(stepsFile, JSON.stringify(j));
console.log(`${j.steps.length} Fingerabdrücke`);
