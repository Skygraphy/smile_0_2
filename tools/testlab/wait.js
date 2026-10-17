// Waits until the person has answered the given step on the Testlab page,
// prints the answer and exits (Claude starts this in the background and is
// woken when it exits).   node tools/testlab/wait.js <stepId> [minutes]
const fs = require('fs');
const path = require('path');

const stepId = process.argv[2];
const minutes = Number(process.argv[3] || 60);
const file = path.join(__dirname, 'run', 'answer.json');
const until = Date.now() + minutes * 60_000;

const timer = setInterval(() => {
  try {
    const answer = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (answer.stepId === stepId) {
      clearInterval(timer);
      console.log(JSON.stringify(answer));
      process.exit(0);
    }
  } catch {}
  if (Date.now() > until) {
    clearInterval(timer);
    console.log(JSON.stringify({ stepId, timeout: true }));
    process.exit(0);
  }
}, 700);
