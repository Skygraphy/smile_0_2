// Frame chime for new photos (Ernst 2026-10-28): "ein ordentlicher Ton" --
// longer and fuller than the album plops, heard from the next room, never shrill.
// node tools/sounds/make3.js <out dir>
const fs = require('fs'), path = require('path'); const SR = 44100;
const out = process.argv[2] || __dirname;
function wav(s) { const b = Buffer.alloc(44 + s.length * 2); b.write('RIFF', 0); b.writeUInt32LE(36 + s.length * 2, 4); b.write('WAVE', 8); b.write('fmt ', 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(s.length * 2, 40); s.forEach((v, i) => b.writeInt16LE(Math.max(-1, Math.min(1, v)) * 32767 | 0, 44 + i * 2)); return b; }
// One struck note: partials [ratio, gain, decay seconds].
function note(buf, start, f0, partials, attack = 0.004, gain = 1) {
  const s0 = Math.round(start * SR);
  for (let i = s0; i < buf.length; i++) {
    const t = (i - s0) / SR; const a = t < attack ? Math.sin(Math.PI / 2 * t / attack) : 1; let v = 0;
    for (const [r, g, d] of partials) v += Math.sin(2 * Math.PI * f0 * r * t) * g * Math.exp(-t / d);
    buf[i] += v * a * gain;
  }
}
function save(buf, name) {
  const peak = Math.max(...buf.map(Math.abs)); for (let i = 0; i < buf.length; i++) buf[i] = buf[i] / peak * 0.85;
  for (let i = 0; i < 800; i++) buf[buf.length - 1 - i] *= i / 800;
  fs.writeFileSync(path.join(out, name + '.wav'), wav(buf));
}
const bell = [[1, 1, 0.9], [2.0, 0.35, 0.5], [2.76, 0.18, 0.3], [5.4, 0.06, 0.12]];
const soft = [[1, 1, 0.7], [2, 0.25, 0.35], [3, 0.08, 0.2]];
const marimba = [[1, 1, 0.35], [4, 0.2, 0.06], [10, 0.04, 0.02]];

// A: Gong -- ding-dong, two bell notes going down (like a doorbell).
let b = new Array(Math.round(2.2 * SR)).fill(0); note(b, 0, 659.3, bell); note(b, 0.45, 523.3, bell); save(b, 'frame_gong');
// B: Glocke -- one warm bell, long fade.
b = new Array(Math.round(2.4 * SR)).fill(0); note(b, 0, 587.3, [[1, 1, 1.2], [2.0, 0.3, 0.6], [3.0, 0.12, 0.35], [4.2, 0.05, 0.2]]); save(b, 'frame_glocke');
// C: Dreiklang -- three soft notes going up (C-E-G).
b = new Array(Math.round(2.0 * SR)).fill(0); [523.3, 659.3, 784.0].forEach((f, i) => note(b, i * 0.18, f, soft, 0.006, 0.8)); save(b, 'frame_dreiklang');
// D: Marimba -- four quick wooden notes, friendly.
b = new Array(Math.round(1.6 * SR)).fill(0); [392.0, 523.3, 659.3, 784.0].forEach((f, i) => note(b, i * 0.11, f, marimba, 0.003, 0.9)); save(b, 'frame_marimba');
console.log('ok');
