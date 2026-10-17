// Smile Testlab (2026-10-17): a small local web page for guided tests.
// Claude drives the real devices (adb), writes the current step to
// run/state.json with screenshots in run/shots/, and waits for the answer
// the person clicks here (run/answer.json, every answer also appended to
// run/log.jsonl). Runs on this PC only; nothing leaves it.
//
//   node tools/testlab/server.js        -> http://localhost:4800
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.TESTLAB_PORT || 4800);
const ROOT = __dirname;
const RUN = path.join(ROOT, 'run');
const SHOTS = path.join(RUN, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });

const readJson = (file, fallback) => {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
};

const types = { '.html': 'text/html; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.js': 'text/javascript' };

function send(res, status, body, type = 'application/json; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  res.end(body);
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    if (req.method === 'GET' && url.pathname === '/') {
      return send(res, 200, fs.readFileSync(path.join(ROOT, 'public', 'index.html')), types['.html']);
    }
    if (req.method === 'GET' && url.pathname === '/api/state') {
      return send(res, 200, JSON.stringify(readJson(path.join(RUN, 'state.json'), { status: 'idle' })));
    }
    if (req.method === 'GET' && url.pathname === '/api/log') {
      let lines = [];
      try {
        lines = fs.readFileSync(path.join(RUN, 'log.jsonl'), 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
      } catch {}
      return send(res, 200, JSON.stringify(lines));
    }
    if (req.method === 'GET' && url.pathname.startsWith('/shots/')) {
      const file = path.join(SHOTS, path.basename(decodeURIComponent(url.pathname)));
      if (!fs.existsSync(file)) return send(res, 404, 'not found', 'text/plain');
      return send(res, 200, fs.readFileSync(file), types[path.extname(file)] || 'application/octet-stream');
    }
    if (req.method === 'POST' && url.pathname === '/api/answer') {
      let body = '';
      req.on('data', (c) => (body += c));
      req.on('end', () => {
        let answer;
        try {
          answer = JSON.parse(body);
        } catch {
          return send(res, 400, '{"error":"bad_json"}');
        }
        const state = readJson(path.join(RUN, 'state.json'), {});
        if (!state.stepId || answer.stepId !== state.stepId) return send(res, 409, '{"error":"old_step"}');
        const entry = { ...answer, title: state.title, at: new Date().toISOString() };
        fs.writeFileSync(path.join(RUN, 'answer.json'), JSON.stringify(entry, null, 1));
        fs.appendFileSync(path.join(RUN, 'log.jsonl'), JSON.stringify(entry) + '\n');
        // The page shows "Claude arbeitet ..." until the next step is there.
        fs.writeFileSync(path.join(RUN, 'state.json'), JSON.stringify({ ...state, status: 'working', answered: entry }, null, 1));
        send(res, 200, '{"ok":true}');
      });
      return;
    }
    send(res, 404, 'not found', 'text/plain');
  })
  .listen(PORT, () => console.log(`Smile Testlab: http://localhost:${PORT}`));
