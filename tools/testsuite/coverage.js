// The coverage map: every tappable element seen on every screen in any
// chapter, and whether it was used (tapped) in a chapter, is promised to a
// later one (coverage.json), or is not tested yet.
//   node coverage.js <out dir> <site data dir>
const fs = require("fs"), path = require("path");
const [outDir, dataDir] = process.argv.slice(2);
const declared = JSON.parse(fs.readFileSync(path.join(__dirname, "coverage.json"), "utf8"));
const aliases = declared._aliases ?? {};

const screens = new Map(); // screen -> Map(label -> {seen:[chapter,step], tested:[...], later})
const taps = []; // {chapter, screen, label}
for (const ch of fs.readdirSync(outDir).filter(d => /^ch\d\d$/.test(d)).sort()) {
  const steps = JSON.parse(fs.readFileSync(path.join(outDir, ch, "steps.json"), "utf8")).steps;
  for (const s of steps) {
    if (!s.screen) continue;
    if (!screens.has(s.screen)) screens.set(s.screen, new Map());
    const m = screens.get(s.screen);
    for (const label of s.elements ?? []) if (!m.has(label)) m.set(label, { seen: { chapter: ch, step: s.no }, tested: [] });
  }
  const tsv = path.join(outDir, ch, "taps.tsv");
  if (fs.existsSync(tsv)) {
    for (const line of fs.readFileSync(tsv, "utf8").split("\n").filter(Boolean)) {
      const [screen, label] = line.split("\t");
      taps.push({ chapter: ch, screen, label });
    }
  }
}

const matches = (element, tap, screen) => {
  const alias = aliases[screen]?.[element];
  if (alias && alias === tap) return true;
  if (tap === "class:android.widget.EditText") return element.startsWith("Eingabefeld");
  return element.startsWith(tap) || tap.startsWith(element);
};

const result = [];
let tested = 0, later = 0, open = 0;
for (const [screen, m] of screens) {
  const elements = [];
  for (const [label, e] of m) {
    const hit = taps.filter(t => t.screen === screen && matches(label, t.label, screen));
    const promise = Object.entries(declared[screen] ?? {}).find(([prefix]) => label.startsWith(prefix));
    let status = "offen", where = null;
    if (hit.length) { status = "geprüft"; where = [...new Set(hit.map(h => h.chapter))]; tested++; }
    else if (promise) { status = "später"; where = [promise[1]]; later++; }
    else open++;
    elements.push({ label, status, where, seen: e.seen });
  }
  elements.sort((a, b) => ["offen", "später", "geprüft"].indexOf(a.status) - ["offen", "später", "geprüft"].indexOf(b.status));
  result.push({ screen, elements });
}
fs.mkdirSync(dataDir, { recursive: true });
fs.writeFileSync(path.join(dataDir, "coverage.json"), JSON.stringify({ tested, later, open, screens: result }));
console.log(`Abdeckung: ${tested} geprüft, ${later} später, ${open} offen`);
