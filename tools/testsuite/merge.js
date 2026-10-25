// Puts the two parts of a chapter that runs on two devices together
// (chapter 6 on: the phone part and the Frame part run at the same time):
//   node merge.js <out/chNN> <out/chNNf>
// Steps are ordered by the time they were recorded ("at"), numbered anew,
// their screenshots renamed to match; taps and a failure note are joined.
// The result replaces out/chNN; the Frame part's folder stays as it was.
const fs = require("fs"), path = require("path");
const [phoneDir, frameDir] = process.argv.slice(2);
const read = (dir) => JSON.parse(fs.readFileSync(path.join(dir, "steps.json"), "utf8"));
const phone = read(phoneDir), frame = read(frameDir);
const all = [
  ...phone.steps.map((s) => ({ s, dir: phoneDir })),
  ...frame.steps.map((s) => ({ s, dir: frameDir })),
].sort((a, b) => (a.s.at ?? 0) - (b.s.at ?? 0));

// Pictures first into memory: the new names overlap the phone's old ones.
const pictures = all.map(({ s, dir }) => fs.readFileSync(path.join(dir, s.image)));
for (const f of fs.readdirSync(phoneDir)) if (/^\d+\.png$/.test(f)) fs.unlinkSync(path.join(phoneDir, f));
const steps = all.map(({ s }, i) => {
  const no = i + 1, image = `${String(no).padStart(2, "0")}.png`;
  fs.writeFileSync(path.join(phoneDir, image), pictures[i]);
  return { ...s, no, image };
});
// The state after a step: the server as that device read it, plus the
// latest known part of each device (handy / frame); the state before a
// step is the state after the previous one, whichever device took it.
const known = {};
for (const s of steps) {
  for (const k of ["handy", "frame"]) if (s.stateAfter && s.stateAfter[k]) known[k] = s.stateAfter[k];
  s.stateAfter = { server: s.stateAfter?.server, ...known };
}
for (let i = 1; i < steps.length; i++) steps[i].stateBefore = steps[i - 1].stateAfter;
fs.writeFileSync(path.join(phoneDir, "steps.json"), JSON.stringify({ ...phone, steps }, null, 1));

const taps = (dir) => (fs.existsSync(path.join(dir, "taps.tsv")) ? fs.readFileSync(path.join(dir, "taps.tsv"), "utf8").trim() : "");
fs.writeFileSync(path.join(phoneDir, "taps.tsv"), [taps(phoneDir), taps(frameDir)].filter(Boolean).join("\n") + "\n");
const failedFrame = path.join(frameDir, "failed.txt");
if (fs.existsSync(failedFrame)) {
  const failedPhone = path.join(phoneDir, "failed.txt");
  const before = fs.existsSync(failedPhone) ? fs.readFileSync(failedPhone, "utf8") + "\n" : "";
  fs.writeFileSync(failedPhone, before + "Frame: " + fs.readFileSync(failedFrame, "utf8"));
}
console.log(`Zusammengeführt: ${phone.steps.length} Schritte am Handy, ${frame.steps.length} am Frame`);
