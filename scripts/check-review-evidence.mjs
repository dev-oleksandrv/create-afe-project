#!/usr/bin/env node
// Validates review evidence that an outside review engine hands to the create-pr skill, with
// Node.js only. The create-pr skill runs it with the current HEAD; on a pass it uses the printed
// line instead of its own review, on a failure it says why and reviews as without the evidence.
//
// The file: JSON Lines, one object per line; blank lines are skipped. Three kinds:
//   {"kind":"review"|"confirm","role":"<role>","input":"plan"|"diff"|"question",
//    "provider":"<name>","model":"<model>"|null,"base":"<merge-base sha or empty>",
//    "head":"<HEAD sha>","dirty":true|false,"coverage":"full"|"tools"|"partial",
//    "at":"<UTC ISO 8601>"}
//     one review by a provider (review), or the narrow confirmation that fixed blockers hold
//     (confirm); dirty is true when the working tree had uncommitted changes to tracked files;
//     coverage is full when the whole input was read, tools when something was cut and the
//     provider could read the repository, partial when something was cut and it could not.
//   {"kind":"finding","role":"<role>","severity":"blocker"|"non-blocker","where":"<file:line>",
//    "answer":"fixed"|"declined"|"open","note":"<one line>"}
//     one answered finding.
//
// Pass (exit 0, one line on stdout): every line is valid JSON of a known kind with these fields;
// the last line of kind review or confirm whose input is diff has head equal to --head, dirty
// false, and coverage full or tools; and no finding is a blocker whose answer is open. The line:
//   Review: external, <provider> (<model>)[, ...], coverage <full|tools>, head <short sha>
// naming each provider, and its model when it has one, of the diff lines at that head, in order.
// Fail: exit 1 and the reason on stderr. Usage errors: exit 2.
//
// Usage: scripts/check-review-evidence.mjs --head <sha> <file>
import { readFileSync } from 'node:fs';

const usage = () => {
  console.error('usage: scripts/check-review-evidence.mjs --head <sha> <file>');
  process.exit(2);
};
const fail = (reason) => {
  console.error(`review evidence: ${reason}`);
  process.exit(1);
};

const args = process.argv.slice(2);
let head = null;
let file = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--head' && i + 1 < args.length) head = args[++i];
  else if (!args[i].startsWith('-') && file === null) file = args[i];
  else usage();
}
if (!head || !/^[0-9a-f]{7,64}$/i.test(head) || !file) usage();
head = head.toLowerCase();

let text;
try {
  text = readFileSync(file, 'utf8');
} catch (e) {
  console.error(`review evidence: cannot read ${file}: ${e.code ?? e.message}`);
  process.exit(2);
}

const str = (v) => typeof v === 'string';
const oneOf = (...values) => (v) => values.includes(v);
const FIELDS = {
  review: {
    role: str,
    input: oneOf('plan', 'diff', 'question'),
    provider: (v) => str(v) && v !== '',
    model: (v) => v === null || str(v),
    base: str,
    head: (v) => str(v) && v !== '',
    dirty: (v) => typeof v === 'boolean',
    coverage: oneOf('full', 'tools', 'partial'),
    at: str,
  },
  finding: {
    role: str,
    severity: oneOf('blocker', 'non-blocker'),
    where: str,
    answer: oneOf('fixed', 'declined', 'open'),
    note: str,
  },
};
FIELDS.confirm = FIELDS.review;

const lines = [];
text.split('\n').forEach((raw, i) => {
  if (!raw.trim()) return;
  const n = i + 1;
  let o;
  try {
    o = JSON.parse(raw);
  } catch {
    fail(`line ${n}: not valid JSON`);
  }
  if (o === null || typeof o !== 'object' || Array.isArray(o)) fail(`line ${n}: not a JSON object`);
  const fields = FIELDS[o.kind];
  if (!fields) fail(`line ${n}: unknown kind ${JSON.stringify(o.kind)}`);
  for (const [k, ok] of Object.entries(fields)) {
    if (!ok(o[k])) fail(`line ${n}: ${o.kind} has an invalid or missing ${k}: ${JSON.stringify(o[k])}`);
  }
  lines.push({ n, ...o });
});

const diff = lines.filter((o) => o.kind !== 'finding' && o.input === 'diff');
if (!diff.length) fail('no review or confirm line of the diff');
const last = diff[diff.length - 1];
if (last.head.toLowerCase() !== head) fail(`line ${last.n}: the last review of the diff is of head ${last.head}, not ${head}`);
if (last.dirty) fail(`line ${last.n}: the last review of the diff read a working tree with uncommitted changes`);
if (last.coverage === 'partial') fail(`line ${last.n}: the last review of the diff has partial coverage`);
const open = lines.filter((o) => o.kind === 'finding' && o.severity === 'blocker' && o.answer === 'open');
if (open.length) fail(`open blocker: ${open.map((o) => `${o.where} (line ${o.n})`).join(', ')}`);

const names = [];
for (const o of diff) {
  if (o.head.toLowerCase() !== head) continue;
  const name = o.model ? `${o.provider} (${o.model})` : o.provider;
  if (!names.includes(name)) names.push(name);
}
console.log(`Review: external, ${names.join(', ')}, coverage ${last.coverage}, head ${head.slice(0, 7)}`);
