// Writes the next step for the Testlab page.
//   node tools/testlab/step.js <step.json>
// step.json: { run, index, total, title, text, shots: [{label, file}],
//              options: [{id, label, kind: "yes"|"no"|"other"}],
//              input: {placeholder} | null, checks: [{label, ok}] }
// "working" instead of options: { status: "working", text }.
const fs = require('fs');
const path = require('path');

const step = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const stepId = step.stepId || `s${Date.now()}`;
const state = { status: step.options ? 'question' : 'working', ...step, stepId, at: new Date().toISOString() };
fs.writeFileSync(path.join(__dirname, 'run', 'state.json'), JSON.stringify(state, null, 1));
console.log(stepId);
