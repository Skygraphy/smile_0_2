// Draws the test portraits (flat symbol pictures, no real person):
// woman and man, each young / mature / old, as 512 px JPEGs into
// fixtures/profiles/ (with labels.json). Renders the SVGs with headless
// Chrome or Edge.   node make_portraits.js
const fs = require("fs"), path = require("path"), { execFileSync } = require("child_process");

const OUT = path.join(__dirname, "fixtures", "profiles");
const BROWSER = process.env.BROWSER || [
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].find(p => fs.existsSync(p));

const people = [
  { file: "frau_jung", label: "Frau, jung", bg: "#8ec5c0", skin: "#f2c7a5", hair: "#3b2a20", shirt: "#e0675a", sex: "f", age: "young" },
  { file: "frau_mittel", label: "Frau, mittleres Alter", bg: "#c9b6e4", skin: "#e8b48f", hair: "#8a3f24", shirt: "#3f6e9e", sex: "f", age: "mature" },
  { file: "frau_alt", label: "Frau, älter", bg: "#f1c98b", skin: "#f0c4a8", hair: "#e4e1dc", shirt: "#7b5ea7", sex: "f", age: "old" },
  { file: "mann_jung", label: "Mann, jung", bg: "#a8cfe8", skin: "#c98d63", hair: "#1f1a17", shirt: "#4a9a6a", sex: "m", age: "young" },
  { file: "mann_mittel", label: "Mann, mittleres Alter", bg: "#f2a99a", skin: "#eab896", hair: "#5a3a26", shirt: "#2f4f6f", sex: "m", age: "mature" },
  { file: "mann_alt", label: "Mann, älter", bg: "#b9d7a6", skin: "#efc2a0", hair: "#d9d6d0", shirt: "#8a5a3c", sex: "m", age: "old" },
];

const shade = (hex, f) => "#" + hex.slice(1).match(/../g)
  .map(h => Math.max(0, Math.min(255, Math.round(parseInt(h, 16) * f))).toString(16).padStart(2, "0")).join("");

function svg(p) {
  const { skin, hair, shirt, sex, age } = p;
  const old = age === "old", mature = age === "mature";
  const line = shade(skin, 0.72), dark = "#2b211c";
  const parts = [];
  parts.push(`<rect width="512" height="512" fill="${p.bg}"/>`);
  // Long hair behind the head (women, not the old one with her bun).
  if (sex === "f" && !old) {
    const len = mature ? 330 : 400;
    parts.push(`<path d="M150 210 Q150 90 256 86 Q362 90 362 210 L370 ${len} Q256 ${len + 26} 142 ${len} Z" fill="${hair}"/>`);
  }
  // Shoulders, neck.
  parts.push(`<path d="M86 512 Q96 392 200 372 L312 372 Q416 392 426 512 Z" fill="${shirt}"/>`);
  parts.push(`<path d="M218 312 L294 312 L300 384 Q256 404 212 384 Z" fill="${shade(skin, 0.9)}"/>`);
  // Ears, head.
  parts.push(`<ellipse cx="160" cy="236" rx="18" ry="28" fill="${shade(skin, 0.94)}"/><ellipse cx="352" cy="236" rx="18" ry="28" fill="${shade(skin, 0.94)}"/>`);
  parts.push(`<ellipse cx="256" cy="226" rx="96" ry="112" fill="${skin}"/>`);
  // Hair on top.
  if (sex === "f") {
    if (old) {
      parts.push(`<circle cx="256" cy="98" r="44" fill="${hair}"/>`);
      parts.push(`<path d="M162 214 Q160 118 256 116 Q352 118 350 214 Q330 150 256 148 Q182 150 162 214 Z" fill="${hair}"/>`);
      parts.push(`<path d="M168 200 Q176 160 214 152" stroke="${shade(hair, 0.85)}" stroke-width="5" fill="none"/>`);
    } else {
      parts.push(`<path d="M160 214 Q158 110 256 108 Q354 110 352 214 Q336 160 290 150 Q250 176 196 168 Q172 180 160 214 Z" fill="${hair}"/>`);
    }
  } else if (old) {
    // Bald on top, grey at the sides.
    parts.push(`<path d="M160 236 Q156 176 178 158 Q182 196 186 236 Z" fill="${hair}"/><path d="M352 236 Q356 176 334 158 Q330 196 326 236 Z" fill="${hair}"/>`);
  } else {
    parts.push(`<path d="M160 206 Q156 112 256 108 Q356 112 352 206 Q344 160 320 150 Q290 166 220 156 Q176 162 160 206 Z" fill="${hair}"/>`);
  }
  // Eyebrows, eyes, nose, mouth.
  const browColor = old ? shade(hair, 0.8) : shade(hair, 0.9);
  parts.push(`<path d="M196 196 Q216 186 236 194" stroke="${browColor}" stroke-width="7" stroke-linecap="round" fill="none"/>`);
  parts.push(`<path d="M276 194 Q296 186 316 196" stroke="${browColor}" stroke-width="7" stroke-linecap="round" fill="none"/>`);
  parts.push(`<circle cx="216" cy="226" r="9" fill="${dark}"/><circle cx="296" cy="226" r="9" fill="${dark}"/>`);
  parts.push(`<path d="M256 236 Q246 268 256 272" stroke="${line}" stroke-width="5" stroke-linecap="round" fill="none"/>`);
  // Moustache and beard.
  if (sex === "m" && mature) {
    parts.push(`<path d="M162 236 Q170 330 256 340 Q342 330 350 236 Q340 300 300 300 Q256 286 212 300 Q172 300 162 236 Z" fill="${hair}"/>`);
  }
  if (sex === "m" && old) {
    parts.push(`<path d="M222 290 Q256 274 290 290 Q280 302 256 296 Q232 302 222 290 Z" fill="${hair}"/>`);
  }
  const smileY = sex === "m" && (mature || old) ? 306 : 294;
  parts.push(`<path d="M226 ${smileY} Q256 ${smileY + 24} 286 ${smileY}" stroke="${sex === "f" ? "#b84a4a" : dark}" stroke-width="6" stroke-linecap="round" fill="none"/>`);
  if (sex === "f" && !old) parts.push(`<ellipse cx="198" cy="262" rx="16" ry="9" fill="#e88" opacity=".35"/><ellipse cx="314" cy="262" rx="16" ry="9" fill="#e88" opacity=".35"/>`);
  // Lines of age: wrinkles, glasses.
  if (old) {
    parts.push(`<path d="M182 230 Q176 238 180 246 M330 230 Q336 238 332 246 M212 158 Q256 148 300 158 M218 172 Q256 164 294 172 M206 286 Q200 300 206 312 M306 286 Q312 300 306 312" stroke="${line}" stroke-width="3.5" stroke-linecap="round" fill="none" opacity=".75"/>`);
    parts.push(`<g fill="none" stroke="#3a3a3a" stroke-width="5"><circle cx="216" cy="226" r="26"/><circle cx="296" cy="226" r="26"/><path d="M242 224 Q256 216 270 224 M190 222 L166 214 M322 222 L346 214"/></g>`);
  } else if (mature) {
    parts.push(`<path d="M186 226 Q182 232 186 238 M326 226 Q330 232 326 238" stroke="${line}" stroke-width="3" stroke-linecap="round" fill="none" opacity=".6"/>`);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">${parts.join("")}</svg>`;
}

fs.mkdirSync(OUT, { recursive: true });
const labels = {};
for (const p of people) {
  const html = path.join(OUT, p.file + ".html");
  fs.writeFileSync(html, `<!doctype html><html><body style="margin:0">${svg(p)}</body></html>`);
  const png = path.join(OUT, p.file + ".png");
  execFileSync(BROWSER, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=512,512",
    "--screenshot=" + png, "file:///" + html.replace(/\\/g, "/")], { stdio: "ignore" });
  fs.unlinkSync(html);
  labels[p.file + ".png"] = p.label;
  console.log(p.file + ".png");
}
fs.writeFileSync(path.join(OUT, "labels.json"), JSON.stringify(labels, null, 1));
