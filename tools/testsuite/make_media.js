// Draws the test pictures and videos (flat symbol pictures like the
// portraits, nothing real): 50 files into fixtures/media/, every 10th a
// short animation. Always the same files. Needs headless Chrome/Edge and
// ffmpeg-static (npm install).   node make_media.js
const fs = require("fs"), path = require("path"), { execFileSync } = require("child_process");
const ffmpeg = process.env.FFMPEG || require("ffmpeg-static");
const OUT = path.join(__dirname, "fixtures", "media");
const TMP = path.join(__dirname, "out", "media_tmp");
const BROWSER = process.env.BROWSER || [
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
].find(p => fs.existsSync(p));

// ------------------------------------------------------------ drawing kit
const times = {
  morgen: { sky: ["#ffd9b0", "#a9d4f2"], sun: "#ffe08a", light: 1.0 },
  mittag: { sky: ["#7cc3f0", "#d8f0ff"], sun: "#ffd54a", light: 1.0 },
  abend: { sky: ["#f28a5b", "#6a4c93"], sun: "#ffb347", light: 0.82 },
  nacht: { sky: ["#0f1a3a", "#2b3d6b"], sun: "#f4f1c9", light: 0.55 },
};
const shade = (hex, f) => "#" + hex.slice(1).match(/../g)
  .map(h => Math.max(0, Math.min(255, Math.round(parseInt(h, 16) * f))).toString(16).padStart(2, "0")).join("");
let gid = 0;
const sky = (w, h, t) => { const id = "g" + (++gid);
  return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${t.sky[1]}"/><stop offset="1" stop-color="${t.sky[0]}"/></linearGradient></defs><rect width="${w}" height="${h}" fill="url(#${id})"/>`; };
const sun = (x, y, r, t) => t === times.nacht
  ? `<circle cx="${x}" cy="${y}" r="${r * 0.8}" fill="${t.sun}"/><circle cx="${x + r * 0.35}" cy="${y - r * 0.2}" r="${r * 0.7}" fill="${t.sky[1]}"/>`
  : `<circle cx="${x}" cy="${y}" r="${r * 1.5}" fill="${t.sun}" opacity=".25"/><circle cx="${x}" cy="${y}" r="${r}" fill="${t.sun}"/>`;
const cloud = (x, y, s, c = "#ffffff", o = 0.9) => `<g fill="${c}" opacity="${o}"><ellipse cx="${x}" cy="${y}" rx="${70 * s}" ry="${34 * s}"/><ellipse cx="${x - 50 * s}" cy="${y + 10 * s}" rx="${50 * s}" ry="${26 * s}"/><ellipse cx="${x + 55 * s}" cy="${y + 8 * s}" rx="${55 * s}" ry="${28 * s}"/></g>`;
const stars = (w, h, n, seed) => { let s = seed, out = ""; const r = () => (s = (s * 9301 + 49297) % 233280) / 233280;
  for (let i = 0; i < n; i++) out += `<circle cx="${(r() * w).toFixed(0)}" cy="${(r() * h * 0.55).toFixed(0)}" r="${(1.5 + r() * 2.5).toFixed(1)}" fill="#fff" opacity="${(0.5 + r() * 0.5).toFixed(2)}"/>`; return out; };
const hill = (w, y, amp, c, phase = 0) => { let d = `M0 ${y}`; for (let x = 0; x <= w; x += 40) d += ` L${x} ${(y - Math.sin(x / w * Math.PI * 2 + phase) * amp - Math.sin(x / w * Math.PI * 5 + phase) * amp * 0.25).toFixed(1)}`; return `<path d="${d} L${w} 99999 L0 99999 Z" fill="${c}"/>`; };
const tree = (x, y, s, leaf = "#3f8f5a", trunk = "#7a5236") => `<rect x="${x - 10 * s}" y="${y - 60 * s}" width="${20 * s}" height="${60 * s}" fill="${trunk}"/><circle cx="${x}" cy="${y - 100 * s}" r="${60 * s}" fill="${leaf}"/><circle cx="${x - 40 * s}" cy="${y - 70 * s}" r="${40 * s}" fill="${leaf}"/><circle cx="${x + 40 * s}" cy="${y - 72 * s}" r="${42 * s}" fill="${shade(leaf, 0.9)}"/>`;
const pine = (x, y, s, c = "#2f6b4a", snow = false) => `<rect x="${x - 8 * s}" y="${y - 30 * s}" width="${16 * s}" height="${30 * s}" fill="#5c3d28"/>` +
  [0, 1, 2].map(i => `<path d="M${x} ${y - (200 - i * 55) * s} L${x + (70 + i * 18) * s} ${y - (90 - i * 30) * s} L${x - (70 + i * 18) * s} ${y - (90 - i * 30) * s} Z" fill="${c}"/>` +
    (snow ? `<path d="M${x} ${y - (200 - i * 55) * s} L${x + 22 * s} ${y - (165 - i * 55) * s} L${x - 22 * s} ${y - (165 - i * 55) * s} Z" fill="#fff"/>` : "")).join("");
const flower = (x, y, s, c) => `<line x1="${x}" y1="${y}" x2="${x}" y2="${y + 50 * s}" stroke="#3f8f5a" stroke-width="${5 * s}"/>` +
  [0, 72, 144, 216, 288].map(a => `<circle cx="${(x + Math.cos(a / 57.3) * 13 * s).toFixed(1)}" cy="${(y + Math.sin(a / 57.3) * 13 * s).toFixed(1)}" r="${10 * s}" fill="${c}"/>`).join("") + `<circle cx="${x}" cy="${y}" r="${8 * s}" fill="#ffd54a"/>`;
const house = (x, y, s, wall, roof) => `<rect x="${x - 120 * s}" y="${y - 160 * s}" width="${240 * s}" height="${160 * s}" fill="${wall}"/><path d="M${x - 150 * s} ${y - 150 * s} L${x} ${y - 270 * s} L${x + 150 * s} ${y - 150 * s} Z" fill="${roof}"/>` +
  `<rect x="${x - 25 * s}" y="${y - 90 * s}" width="${50 * s}" height="${90 * s}" fill="${shade(roof, 0.8)}"/><rect x="${x - 95 * s}" y="${y - 125 * s}" width="${45 * s}" height="${45 * s}" fill="#ffe8a8"/><rect x="${x + 50 * s}" y="${y - 125 * s}" width="${45 * s}" height="${45 * s}" fill="#ffe8a8"/>`;
const boat = (x, y, s, sail = "#ffffff", hull = "#d9534f") => `<path d="M${x - 110 * s} ${y} L${x + 110 * s} ${y} L${x + 80 * s} ${y + 40 * s} L${x - 80 * s} ${y + 40 * s} Z" fill="${hull}"/><rect x="${x - 4 * s}" y="${y - 200 * s}" width="${8 * s}" height="${200 * s}" fill="#5c3d28"/><path d="M${x + 6 * s} ${y - 190 * s} L${x + 100 * s} ${y - 20 * s} L${x + 6 * s} ${y - 20 * s} Z" fill="${sail}"/><path d="M${x - 6 * s} ${y - 160 * s} L${x - 75 * s} ${y - 20 * s} L${x - 6 * s} ${y - 20 * s} Z" fill="${shade(sail, 0.9)}"/>`;
const balloon = (x, y, s, c) => `<line x1="${x}" y1="${y + 60 * s}" x2="${x + 10 * s}" y2="${y + 170 * s}" stroke="#555" stroke-width="${2 * s}"/><ellipse cx="${x}" cy="${y}" rx="${48 * s}" ry="${60 * s}" fill="${c}"/><ellipse cx="${x - 16 * s}" cy="${y - 20 * s}" rx="${10 * s}" ry="${16 * s}" fill="#fff" opacity=".35"/><path d="M${x - 8 * s} ${y + 58 * s} L${x + 8 * s} ${y + 58 * s} L${x} ${y + 68 * s} Z" fill="${c}"/>`;
const dog = (x, y, s, c = "#c98d52") => `<g transform="translate(${x} ${y}) scale(${s})"><ellipse cx="0" cy="0" rx="110" ry="55" fill="${c}"/><rect x="-85" y="20" width="26" height="80" rx="10" fill="${c}"/><rect x="55" y="20" width="26" height="80" rx="10" fill="${c}"/><rect x="-40" y="25" width="24" height="72" rx="10" fill="${shade(c, 0.88)}"/><rect x="20" y="25" width="24" height="72" rx="10" fill="${shade(c, 0.88)}"/><path d="M-105 -20 Q-150 -60 -140 -95" stroke="${c}" stroke-width="18" fill="none" stroke-linecap="round"/><circle cx="110" cy="-50" r="55" fill="${c}"/><ellipse cx="150" cy="-35" rx="30" ry="22" fill="${shade(c, 1.1)}"/><circle cx="174" cy="-40" r="9" fill="#2b211c"/><circle cx="120" cy="-62" r="7" fill="#2b211c"/><ellipse cx="80" cy="-60" rx="20" ry="40" fill="${shade(c, 0.7)}" transform="rotate(20 80 -60)"/></g>`;
const cat = (x, y, s, c = "#8a8f99") => `<g transform="translate(${x} ${y}) scale(${s})"><ellipse cx="0" cy="40" rx="90" ry="110" fill="${c}"/><path d="M70 120 Q170 110 150 10" stroke="${c}" stroke-width="22" fill="none" stroke-linecap="round"/><circle cx="0" cy="-90" r="75" fill="${c}"/><path d="M-62 -130 L-45 -205 L-10 -150 Z M62 -130 L45 -205 L10 -150 Z" fill="${c}"/><ellipse cx="-27" cy="-95" rx="11" ry="16" fill="#9be07a"/><ellipse cx="27" cy="-95" rx="11" ry="16" fill="#9be07a"/><ellipse cx="-27" cy="-95" rx="4" ry="12" fill="#222"/><ellipse cx="27" cy="-95" rx="4" ry="12" fill="#222"/><path d="M-8 -62 L8 -62 L0 -52 Z" fill="#e88"/><path d="M-60 -60 L-110 -70 M-60 -52 L-110 -48 M60 -60 L110 -70 M60 -52 L110 -48" stroke="#eee" stroke-width="3"/></g>`;

// ------------------------------------------------------------ scenes
const scenes = {
  strand: (w, h, t) => sky(w, h, t) + sun(w * 0.75, h * 0.22, h * 0.07, t) + cloud(w * 0.25, h * 0.18, h / 900) +
    `<rect y="${h * 0.55}" width="${w}" height="${h * 0.2}" fill="${shade("#3fa7c9", t.light)}"/>` + hill(w, h * 0.72, h * 0.02, shade("#f2d49b", t.light)) +
    `<path d="M${w * 0.3} ${h * 0.78} L${w * 0.3} ${h * 0.6}" stroke="#7a5236" stroke-width="${h * 0.012}"/><path d="M${w * 0.2} ${h * 0.62} Q${w * 0.3} ${h * 0.5} ${w * 0.4} ${h * 0.62} Z" fill="#e0675a"/>` +
    `<ellipse cx="${w * 0.6}" cy="${h * 0.85}" rx="${w * 0.08}" ry="${h * 0.02}" fill="#5aa0d8"/>`,
  berge: (w, h, t) => sky(w, h, t) + sun(w * 0.2, h * 0.2, h * 0.06, t) + cloud(w * 0.7, h * 0.15, h / 1000) +
    `<path d="M0 ${h * 0.7} L${w * 0.25} ${h * 0.3} L${w * 0.45} ${h * 0.6} L${w * 0.65} ${h * 0.25} L${w} ${h * 0.65} L${w} ${h} L0 ${h} Z" fill="${shade("#6b7a99", t.light)}"/>` +
    `<path d="M${w * 0.25} ${h * 0.3} L${w * 0.31} ${h * 0.4} L${w * 0.19} ${h * 0.4} Z M${w * 0.65} ${h * 0.25} L${w * 0.72} ${h * 0.36} L${w * 0.58} ${h * 0.36} Z" fill="#fff"/>` +
    hill(w, h * 0.78, h * 0.04, shade("#5c9e5a", t.light)) + pine(w * 0.15, h * 0.9, h / 900, shade("#2f6b4a", t.light)) + pine(w * 0.85, h * 0.92, h / 800, shade("#2f6b4a", t.light)),
  see: (w, h, t) => sky(w, h, t) + sun(w * 0.6, h * 0.2, h * 0.06, t) +
    hill(w, h * 0.5, h * 0.05, shade("#5c9e5a", t.light)) + `<rect y="${h * 0.55}" width="${w}" height="${h * 0.45}" fill="${shade("#4f8fc0", t.light)}"/>` +
    [0.1, 0.22, 0.34, 0.75, 0.88].map((x, i) => pine(w * x, h * 0.56, h / (1100 + i * 80), shade("#2f6b4a", t.light))).join("") +
    `<g opacity=".25" transform="translate(0 ${h * 1.12}) scale(1 -1)">${[0.1, 0.22, 0.34, 0.75, 0.88].map((x, i) => pine(w * x, h * 0.56, h / (1100 + i * 80), "#1d3c2c")).join("")}</g>`,
  sonnenuntergang: (w, h) => { const t = times.abend; return sky(w, h, t) + sun(w * 0.5, h * 0.55, h * 0.11, t) +
    `<rect y="${h * 0.58}" width="${w}" height="${h * 0.42}" fill="#3d3a6b"/>` + [0, 1, 2, 3].map(i => `<rect x="${w * 0.5 - w * (0.12 - i * 0.025)}" y="${h * (0.62 + i * 0.06)}" width="${w * (0.24 - i * 0.05)}" height="${h * 0.012}" fill="#ffb347" opacity=".7"/>`).join("") +
    cloud(w * 0.2, h * 0.25, h / 1000, "#f6a28a", 0.7) + cloud(w * 0.78, h * 0.32, h / 1200, "#f6a28a", 0.7); },
  nacht: (w, h) => { const t = times.nacht; return sky(w, h, t) + stars(w, h, 90, 7) + sun(w * 0.78, h * 0.2, h * 0.07, t) +
    hill(w, h * 0.72, h * 0.06, "#1f2d4d") + hill(w, h * 0.84, h * 0.04, "#15203a", 1.3) + house(w * 0.3, h * 0.86, h / 1600, "#3a4466", "#22293f"); },
  haus: (w, h, t) => sky(w, h, t) + sun(w * 0.82, h * 0.18, h * 0.06, t) + cloud(w * 0.35, h * 0.15, h / 1000) +
    hill(w, h * 0.7, h * 0.02, shade("#7cbf62", t.light)) + house(w * 0.45, h * 0.78, h / 900, "#f3e2c7", "#c0504d") +
    tree(w * 0.12, h * 0.8, h / 900, shade("#4f9d5c", t.light)) + tree(w * 0.82, h * 0.82, h / 1000, shade("#3f8f5a", t.light)) +
    [0.25, 0.3, 0.62, 0.68].map((x, i) => flower(w * x, h * 0.84, h / 1200, ["#e0675a", "#f2c14e", "#b86fd1", "#ff8fb1"][i])).join(""),
  wiese: (w, h, t) => sky(w, h, t) + sun(w * 0.3, h * 0.18, h * 0.06, t) + cloud(w * 0.7, h * 0.2, h / 1000) +
    hill(w, h * 0.55, h * 0.04, shade("#8bc56a", t.light)) + hill(w, h * 0.68, h * 0.03, shade("#6fb45a", t.light), 2) +
    Array.from({ length: 36 }, (_, i) => flower(w * ((i * 0.137) % 1), h * (0.7 + ((i * 7) % 10) / 40), h / (1000 + (i % 4) * 150), ["#e0675a", "#f2c14e", "#b86fd1", "#ff8fb1", "#ffffff"][i % 5])).join(""),
  herbstwald: (w, h, t) => sky(w, h, t) + sun(w * 0.7, h * 0.2, h * 0.05, t) + hill(w, h * 0.8, h * 0.02, shade("#c98a4b", t.light)) +
    [0.08, 0.24, 0.4, 0.56, 0.72, 0.9].map((x, i) => tree(w * x, h * (0.84 + (i % 2) * 0.04), h / (700 + (i % 3) * 120), shade(["#e07a3a", "#d9a03f", "#c0504d"][i % 3], t.light), "#6b4430")).join("") +
    Array.from({ length: 30 }, (_, i) => `<ellipse cx="${w * ((i * 0.173) % 1)}" cy="${h * (0.88 + (i % 5) / 50)}" rx="${h / 90}" ry="${h / 160}" fill="${["#e07a3a", "#d9a03f", "#c0504d"][i % 3]}"/>`).join(""),
  winter: (w, h, t) => sky(w, h, t) + sun(w * 0.8, h * 0.18, h * 0.05, t) + hill(w, h * 0.65, h * 0.05, "#f4f7fb") + hill(w, h * 0.8, h * 0.03, "#e6edf5", 1) +
    pine(w * 0.12, h * 0.72, h / 900, "#2f6b4a", true) + pine(w * 0.86, h * 0.7, h / 1000, "#2f6b4a", true) +
    `<circle cx="${w * 0.5}" cy="${h * 0.8}" r="${h * 0.1}" fill="#fff"/><circle cx="${w * 0.5}" cy="${h * 0.64}" r="${h * 0.07}" fill="#fff"/><circle cx="${w * 0.5}" cy="${h * 0.52}" r="${h * 0.05}" fill="#fff"/>` +
    `<path d="M${w * 0.5} ${h * 0.52} L${w * 0.54} ${h * 0.53} L${w * 0.5} ${h * 0.535} Z" fill="#f08a3a"/><circle cx="${w * 0.49}" cy="${h * 0.51}" r="${h * 0.005}" fill="#222"/><circle cx="${w * 0.51}" cy="${h * 0.51}" r="${h * 0.005}" fill="#222"/>` +
    stars(w, h * 1.6, 70, 3).replace(/fill="#fff"/g, 'fill="#ffffff"'),
  torte: (w, h) => `<rect width="${w}" height="${h}" fill="#f6d9e3"/><ellipse cx="${w / 2}" cy="${h * 0.78}" rx="${w * 0.33}" ry="${h * 0.07}" fill="#ffffff"/>` +
    `<rect x="${w * 0.25}" y="${h * 0.48}" width="${w * 0.5}" height="${h * 0.28}" fill="#8b5a3c"/><ellipse cx="${w / 2}" cy="${h * 0.76}" rx="${w * 0.25}" ry="${h * 0.05}" fill="#8b5a3c"/><ellipse cx="${w / 2}" cy="${h * 0.48}" rx="${w * 0.25}" ry="${h * 0.06}" fill="#ffb6c8"/>` +
    `<path d="M${w * 0.25} ${h * 0.5} ${Array.from({ length: 10 }, (_, i) => `Q${w * (0.275 + i * 0.05)} ${h * 0.6} ${w * (0.3 + i * 0.05)} ${h * 0.5}`).join(" ")}" fill="#ffb6c8"/>` +
    [0.36, 0.43, 0.5, 0.57, 0.64].map((x, i) => `<rect x="${w * x - w * 0.008}" y="${h * 0.34}" width="${w * 0.016}" height="${h * 0.12}" fill="${["#6fb4e0", "#f2c14e", "#e0675a", "#9bd17a", "#b86fd1"][i]}"/><ellipse cx="${w * x}" cy="${h * 0.32}" rx="${w * 0.01}" ry="${h * 0.022}" fill="#ffb347"/>`).join(""),
  pizza: (w, h) => `<rect width="${w}" height="${h}" fill="#5b4636"/><circle cx="${w / 2}" cy="${h / 2}" r="${h * 0.42}" fill="#e8b874"/><circle cx="${w / 2}" cy="${h / 2}" r="${h * 0.37}" fill="#d9472f"/>` +
    Array.from({ length: 14 }, (_, i) => `<circle cx="${w / 2 + Math.cos(i * 2.4) * h * (0.08 + (i % 4) * 0.07)}" cy="${h / 2 + Math.sin(i * 2.4) * h * (0.08 + (i % 4) * 0.07)}" r="${h * 0.035}" fill="#a83224"/>`).join("") +
    Array.from({ length: 12 }, (_, i) => `<ellipse cx="${w / 2 + Math.cos(i * 1.7) * h * (0.1 + (i % 3) * 0.08)}" cy="${h / 2 + Math.sin(i * 1.7) * h * (0.1 + (i % 3) * 0.08)}" rx="${h * 0.03}" ry="${h * 0.018}" fill="#f6e7b0"/>`).join("") +
    [0, 1, 2].map(i => `<line x1="${w / 2}" y1="${h / 2}" x2="${w / 2 + Math.cos(i * 2.09) * h * 0.42}" y2="${h / 2 + Math.sin(i * 2.09) * h * 0.42}" stroke="#c99a5a" stroke-width="${h * 0.006}"/>`).join(""),
  hund: (w, h, t) => sky(w, h, t) + cloud(w * 0.7, h * 0.18, h / 1000) + hill(w, h * 0.6, h * 0.02, shade("#7cbf62", t.light)) + dog(w * 0.45, h * 0.62, h / 900) +
    `<circle cx="${w * 0.8}" cy="${h * 0.82}" r="${h * 0.04}" fill="#e0675a"/>`,
  katze: (w, h) => `<rect width="${w}" height="${h}" fill="#e9dcc8"/><rect y="${h * 0.7}" width="${w}" height="${h * 0.3}" fill="#b98a5e"/>` +
    `<rect x="${w * 0.08}" y="${h * 0.12}" width="${w * 0.28}" height="${h * 0.32}" fill="#9fd0f0" stroke="#fff" stroke-width="${h * 0.015}"/>` + cat(w * 0.6, h * 0.55, h / 900) +
    `<circle cx="${w * 0.25}" cy="${h * 0.82}" r="${h * 0.05}" fill="#d9534f"/><path d="M${w * 0.25} ${h * 0.82} q${h * 0.1} ${h * 0.05} ${h * 0.15} -${h * 0.02}" stroke="#d9534f" stroke-width="${h * 0.006}" fill="none"/>`,
  segelboot: (w, h, t) => sky(w, h, t) + sun(w * 0.8, h * 0.22, h * 0.06, t) + cloud(w * 0.3, h * 0.2, h / 1000) +
    `<rect y="${h * 0.62}" width="${w}" height="${h * 0.38}" fill="${shade("#3f7fb8", t.light)}"/>` + boat(w * 0.45, h * 0.66, h / 800) +
    [0.7, 0.78, 0.86].map(y => `<path d="M0 ${h * y} ${Array.from({ length: 16 }, (_, i) => `q${w / 32} -${h * 0.015} ${w / 16} 0`).join(" ")}" stroke="#ffffff" stroke-width="${h * 0.004}" fill="none" opacity=".5"/>`).join(""),
  leuchtturm: (w, h, t) => sky(w, h, t) + (t === times.nacht ? stars(w, h, 60, 5) : cloud(w * 0.7, h * 0.18, h / 1000)) +
    `<rect y="${h * 0.7}" width="${w}" height="${h * 0.3}" fill="${shade("#3f7fb8", t.light)}"/>` + hill(w * 0.6, h * 0.72, h * 0.04, shade("#7a756c", t.light)) +
    `<path d="M${w * 0.25} ${h * 0.7} L${w * 0.28} ${h * 0.3} L${w * 0.34} ${h * 0.3} L${w * 0.37} ${h * 0.7} Z" fill="#ffffff"/>` +
    [0.36, 0.5, 0.62].map(y => `<path d="M${w * (0.27 - (y - 0.3) * 0.05)} ${h * y} L${w * (0.35 + (y - 0.3) * 0.05)} ${h * y} L${w * (0.355 + (y - 0.3) * 0.05)} ${h * (y + 0.05)} L${w * (0.265 - (y - 0.3) * 0.05)} ${h * (y + 0.05)} Z" fill="#d9534f"/>`).join("") +
    `<rect x="${w * 0.285}" y="${h * 0.22}" width="${w * 0.05}" height="${h * 0.08}" fill="${t === times.nacht ? "#ffe680" : "#fff6c9"}"/><path d="M${w * 0.27} ${h * 0.22} L${w * 0.31} ${h * 0.17} L${w * 0.35} ${h * 0.22} Z" fill="#d9534f"/>` +
    (t === times.nacht ? `<path d="M${w * 0.31} ${h * 0.26} L${w} ${h * 0.12} L${w} ${h * 0.36} Z" fill="#ffe680" opacity=".25"/>` : ""),
  regenbogen: (w, h, t) => sky(w, h, t) + ["#e0675a", "#f29a4a", "#f2d04e", "#7cc16a", "#5aa0d8", "#8a6fd1"].map((c, i) =>
    `<path d="M${w * 0.1 + i * h * 0.03} ${h * 0.75} A${w * 0.4 - i * h * 0.03} ${h * 0.5 - i * h * 0.03} 0 0 1 ${w * 0.9 - i * h * 0.03} ${h * 0.75}" stroke="${c}" stroke-width="${h * 0.03}" fill="none"/>`).join("") +
    cloud(w * 0.12, h * 0.72, h / 700) + cloud(w * 0.88, h * 0.72, h / 700) + hill(w, h * 0.82, h * 0.03, shade("#7cbf62", t.light)),
  ballon: (w, h, t) => sky(w, h, t) + cloud(w * 0.2, h * 0.3, h / 900) + cloud(w * 0.75, h * 0.6, h / 1100) + hill(w, h * 0.88, h * 0.03, shade("#7cbf62", t.light)) +
    `<g transform="translate(${w * 0.5} ${h * 0.35}) scale(${h / 700})"><path d="M-110 0 A110 120 0 1 1 110 0 Q60 90 30 150 L-30 150 Q-60 90 -110 0 Z" fill="#e0675a"/>` +
    `<path d="M-40 -115 Q-70 0 -30 150 L-10 150 Q-35 0 -15 -120 Z" fill="#f2d04e"/><path d="M40 -115 Q70 0 30 150 L10 150 Q35 0 15 -120 Z" fill="#f2d04e"/>` +
    `<line x1="-28" y1="150" x2="-22" y2="190" stroke="#5c3d28" stroke-width="4"/><line x1="28" y1="150" x2="22" y2="190" stroke="#5c3d28" stroke-width="4"/><rect x="-28" y="190" width="56" height="40" fill="#8b5a3c"/></g>`,
  fahrrad: (w, h, t) => sky(w, h, t) + sun(w * 0.15, h * 0.2, h * 0.05, t) + `<rect y="${h * 0.72}" width="${w}" height="${h * 0.28}" fill="#9a9a9a"/><rect y="${h * 0.7}" width="${w}" height="${h * 0.03}" fill="#c9c9c9"/>` +
    `<g transform="translate(${w * 0.5} ${h * 0.6}) scale(${h / 800})" fill="none" stroke-width="10"><circle cx="-130" cy="60" r="85" stroke="#333"/><circle cx="130" cy="60" r="85" stroke="#333"/>` +
    `<path d="M-130 60 L-40 -40 L80 -40 L130 60 M-40 -40 L0 60 L80 -40 M0 60 L-130 60" stroke="#2f8f8a"/><path d="M-60 -60 L-20 -60 M80 -40 L70 -90 L100 -95" stroke="#333"/></g>`,
  kaffee: (w, h) => `<rect width="${w}" height="${h}" fill="#e7d6c0"/><ellipse cx="${w / 2}" cy="${h * 0.7}" rx="${h * 0.36}" ry="${h * 0.08}" fill="#ffffff"/>` +
    `<path d="M${w / 2 - h * 0.22} ${h * 0.35} L${w / 2 + h * 0.22} ${h * 0.35} L${w / 2 + h * 0.18} ${h * 0.68} L${w / 2 - h * 0.18} ${h * 0.68} Z" fill="#ffffff"/>` +
    `<path d="M${w / 2 + h * 0.21} ${h * 0.42} q${h * 0.12} 0 ${h * 0.1} ${h * 0.1} q-${h * 0.02} ${h * 0.08} -${h * 0.12} ${h * 0.06}" stroke="#ffffff" stroke-width="${h * 0.03}" fill="none"/>` +
    `<ellipse cx="${w / 2}" cy="${h * 0.35}" rx="${h * 0.22}" ry="${h * 0.04}" fill="#8b5a3c"/><ellipse cx="${w / 2}" cy="${h * 0.35}" rx="${h * 0.1}" ry="${h * 0.018}" fill="#e8c9a0"/>` +
    [-0.06, 0, 0.06].map(x => `<path d="M${w / 2 + h * x} ${h * 0.28} q${h * 0.03} -${h * 0.05} 0 -${h * 0.1} q-${h * 0.03} -${h * 0.05} 0 -${h * 0.1}" stroke="#ffffff" stroke-width="${h * 0.01}" fill="none" opacity=".7"/>`).join(""),
  obst: (w, h) => `<rect width="${w}" height="${h}" fill="#f1e6d2"/><path d="M${w * 0.2} ${h * 0.55} Q${w / 2} ${h * 0.95} ${w * 0.8} ${h * 0.55} Z" fill="#b8865b"/>` +
    [[0.38, 0.5, "#d9473f", 0.09], [0.5, 0.45, "#f2a03d", 0.1], [0.62, 0.5, "#8ccf5a", 0.09], [0.45, 0.38, "#7a3e9d", 0.06], [0.56, 0.36, "#d9473f", 0.06]].map(([x, y, c, r]) => `<circle cx="${w * x}" cy="${h * y}" r="${h * r}" fill="${c}"/><ellipse cx="${w * x - h * r * 0.35}" cy="${h * y - h * r * 0.4}" rx="${h * r * 0.2}" ry="${h * r * 0.3}" fill="#fff" opacity=".3"/>`).join("") +
    `<path d="M${w * 0.62} ${h * 0.41} l${h * 0.03} -${h * 0.06}" stroke="#5c3d28" stroke-width="${h * 0.01}"/><ellipse cx="${w * 0.66}" cy="${h * 0.34}" rx="${h * 0.03}" ry="${h * 0.015}" fill="#3f8f5a"/>`,
  stadt: (w, h, t) => sky(w, h, t) + (t === times.nacht ? stars(w, h, 50, 9) : sun(w * 0.8, h * 0.2, h * 0.05, t)) +
    [[0.02, 0.45, 0.12], [0.15, 0.3, 0.1], [0.27, 0.5, 0.14], [0.43, 0.25, 0.09], [0.54, 0.4, 0.13], [0.69, 0.33, 0.1], [0.81, 0.48, 0.17]].map(([x, top, bw], i) =>
      `<rect x="${w * x}" y="${h * top}" width="${w * bw}" height="${h}" fill="${shade(["#5b6b8c", "#6f7fa0", "#4f5d7a"][i % 3], t.light)}"/>` +
      Array.from({ length: 18 }, (_, k) => `<rect x="${w * x + w * bw * (0.15 + (k % 3) * 0.28)}" y="${h * top + h * 0.03 + Math.floor(k / 3) * h * 0.06}" width="${w * bw * 0.16}" height="${h * 0.03}" fill="${t === times.nacht ? (k % 4 ? "#ffe08a" : "#2b3550") : "#cfe3f5"}"/>`).join("")).join("") +
    `<rect y="${h * 0.9}" width="${w}" height="${h * 0.1}" fill="#3a3a3a"/>`,
  drachen: (w, h, t) => sky(w, h, t) + cloud(w * 0.75, h * 0.2, h / 1000) + hill(w, h * 0.78, h * 0.04, shade("#7cbf62", t.light)) +
    `<g transform="translate(${w * 0.62} ${h * 0.3}) rotate(15) scale(${h / 900})"><path d="M0 -110 L80 0 L0 150 L-80 0 Z" fill="#e0675a"/><path d="M0 -110 L0 150 M-80 0 L80 0" stroke="#fff" stroke-width="5"/><path d="M0 150 q30 60 0 120 q-30 60 0 120" stroke="#5c3d28" stroke-width="4" fill="none"/>` +
    [0, 1, 2].map(i => `<path d="M-14 ${200 + i * 70} L14 ${215 + i * 70} L-14 ${230 + i * 70} Z" fill="${["#f2d04e", "#5aa0d8", "#7cc16a"][i]}"/>`).join("") + `</g>` +
    `<line x1="${w * 0.62}" y1="${h * 0.42}" x2="${w * 0.3}" y2="${h * 0.86}" stroke="#555" stroke-width="2"/>`,
  fische: (w, h) => `<rect width="${w}" height="${h}" fill="#2f7fb8"/><rect y="${h * 0.85}" width="${w}" height="${h * 0.15}" fill="#e8d3a0"/>` +
    Array.from({ length: 6 }, (_, i) => { const x = w * (0.15 + i * 0.14), y = h * (0.25 + (i % 3) * 0.18), s = h / (900 + (i % 2) * 300), c = ["#f29a4a", "#f2d04e", "#e0675a", "#8ad1c9"][i % 4];
      return `<g transform="translate(${x} ${y}) scale(${i % 2 ? -s : s} ${s})"><ellipse cx="0" cy="0" rx="70" ry="40" fill="${c}"/><path d="M60 0 L110 -35 L110 35 Z" fill="${c}"/><circle cx="-38" cy="-8" r="8" fill="#222"/></g>`; }).join("") +
    Array.from({ length: 14 }, (_, i) => `<circle cx="${w * ((i * 0.071) % 1)}" cy="${h * (0.1 + (i % 7) * 0.1)}" r="${h * 0.008}" fill="#ffffff" opacity=".5"/>`).join("") +
    [0.08, 0.9].map(x => `<path d="M${w * x} ${h * 0.86} q${h * 0.05} -${h * 0.15} 0 -${h * 0.3} q-${h * 0.05} -${h * 0.1} 0 -${h * 0.2}" stroke="#3f8f5a" stroke-width="${h * 0.02}" fill="none"/>`).join(""),
};

// 45 pictures: scene x time of day, every 6th upright.
const plan = [
  ["strand", "mittag", "Strand"], ["berge", "morgen", "Berge am Morgen"], ["see", "mittag", "See"], ["haus", "mittag", "Haus mit Garten"], ["hund", "mittag", "Hund"],
  ["katze", null, "Katze"], ["torte", null, "Geburtstagstorte"], ["pizza", null, "Pizza"], ["wiese", "morgen", "Blumenwiese"],
  ["herbstwald", "mittag", "Herbstwald"], ["winter", "mittag", "Schneemann"], ["sonnenuntergang", null, "Sonnenuntergang"], ["segelboot", "mittag", "Segelboot"], ["leuchtturm", "mittag", "Leuchtturm"],
  ["regenbogen", "mittag", "Regenbogen"], ["ballon", "morgen", "Heißluftballon"], ["fahrrad", "mittag", "Fahrrad"], ["kaffee", null, "Kaffee"],
  ["obst", null, "Obstschale"], ["stadt", "mittag", "Stadt"], ["drachen", "mittag", "Drachen"], ["fische", null, "Fische"], ["nacht", null, "Nacht"],
  ["strand", "abend", "Strand am Abend"], ["berge", "abend", "Berge am Abend"], ["see", "morgen", "See am Morgen"],
  ["haus", "abend", "Haus am Abend"], ["stadt", "nacht", "Stadt bei Nacht"], ["leuchtturm", "nacht", "Leuchtturm bei Nacht"], ["segelboot", "abend", "Segelboot am Abend"],
  ["hund", "morgen", "Hund am Morgen"], ["wiese", "mittag", "Wiese am Mittag"], ["herbstwald", "abend", "Herbstwald am Abend"], ["winter", "morgen", "Winter am Morgen"],
  ["ballon", "mittag", "Ballon am Mittag"], ["drachen", "morgen", "Drachen am Morgen"], ["regenbogen", "morgen", "Regenbogen am Morgen"],
  ["fahrrad", "abend", "Fahrrad am Abend"], ["strand", "morgen", "Strand am Morgen"], ["berge", "mittag", "Berge am Mittag"], ["see", "abend", "See am Abend"],
  ["stadt", "abend", "Stadt am Abend"], ["haus", "morgen", "Haus am Morgen"], ["katze", null, "Katze am Fenster"], ["torte", null, "Torte mit Kerzen"],
];

// 5 animations: background scene + a sprite moving over it (ffmpeg overlay).
const videos = [
  { label: "Segelboot fährt", bg: ["strand", "mittag"], w: 1280, h: 720, sprite: (s) => boat(150, 230, 0.9), sw: 300, sh: 300,
    move: "x='-300+t*190':y='175+6*sin(t*3)'" },
  { label: "Luftballons", bg: ["wiese", "mittag"], w: 1280, h: 720,
    sprite: () => balloon(70, 80, 1, "#e0675a") + balloon(170, 120, 0.9, "#f2d04e") + balloon(260, 70, 1.1, "#5aa0d8"), sw: 340, sh: 300,
    move: "x='470+20*sin(t*2)':y='720-t*120'" },
  { label: "Sonne geht unter", bg: ["sonnenuntergang", null], w: 1280, h: 720, sprite: () => sun(110, 110, 70, times.abend), sw: 220, sh: 220,
    move: "x='530':y='120+t*40'" },
  { label: "Hund läuft", bg: ["wiese", "morgen"], w: 1280, h: 720, sprite: () => dog(230, 160, 0.9), sw: 420, sh: 280,
    move: "x='-420+t*230':y='420+10*abs(sin(t*6))'" },
  { label: "Schneefall", bg: ["winter", "morgen"], w: 720, h: 1280, upright: true,
    sprite: () => { let r = 11; const rnd = () => (r = (r * 9301 + 49297) % 233280) / 233280; return Array.from({ length: 90 }, (_, i) => `<circle cx="${Math.round(rnd() * 720)}" cy="${Math.round(rnd() * 1280)}" r="${4 + (i % 4) * 2}" fill="#ffffff" opacity=".9"/>`).join(""); }, sw: 720, sh: 1280,
    move: "x='0':y='mod(t*90,1280)-1280'", second: "x='0':y='mod(t*90,1280)'" },
];

// ------------------------------------------------------------ rendering
function render(svgBody, w, h, file, transparent = false) {
  const html = path.join(TMP, "r.html");
  fs.writeFileSync(html, `<!doctype html><html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${svgBody}</svg></body></html>`);
  execFileSync(BROWSER, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    `--window-size=${w},${h}`, ...(transparent ? ["--default-background-color=00000000"] : []),
    "--screenshot=" + file, "file:///" + html.replace(/\\/g, "/")], { stdio: "ignore" });
}
const slug = s => s.toLowerCase().replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss").replace(/[^a-z0-9]+/g, "_").replace(/_$/, "");

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(TMP, { recursive: true });
const labels = {};
let p = 0, v = 0;
for (let n = 1; n <= 50; n++) {
  const num = String(n).padStart(2, "0");
  if (n % 10 === 0) {
    const vid = videos[v++], file = `${num}_${slug(vid.label)}.mp4`;
    const bg = path.join(TMP, "bg.png"), sp = path.join(TMP, "sp.png");
    render(scenes[vid.bg[0]](vid.w, vid.h, times[vid.bg[1]] ?? times.mittag), vid.w, vid.h, bg);
    render(vid.sprite(), vid.sw, vid.sh, sp, true);
    const filter = vid.second
      ? `[0][1]overlay=${vid.move}[a];[a][1]overlay=${vid.second},format=yuv420p`
      : `[0][1]overlay=${vid.move},format=yuv420p`;
    execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-loop", "1", "-framerate", "30", "-i", bg, "-loop", "1", "-framerate", "30", "-i", sp,
      "-filter_complex", filter, "-t", "8", "-c:v", "libx264", "-preset", "medium", "-crf", "24", "-movflags", "+faststart", path.join(OUT, file)]);
    labels[file] = vid.label;
  } else {
    const [scene, time, label] = plan[p++];
    const upright = n % 6 === 0;
    const w = upright ? 1200 : 1600, h = upright ? 1600 : 1200;
    const png = path.join(TMP, "pic.png"), file = `${num}_${slug(label)}.jpg`;
    render(scenes[scene](w, h, times[time] ?? times.mittag), w, h, png);
    execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-i", png, "-q:v", "3", path.join(OUT, file)]);
    labels[file] = label;
  }
  console.log(num, labels[Object.keys(labels).pop()]);
}
fs.writeFileSync(path.join(OUT, "labels.json"), JSON.stringify(labels, null, 1));
fs.rmSync(TMP, { recursive: true, force: true });
