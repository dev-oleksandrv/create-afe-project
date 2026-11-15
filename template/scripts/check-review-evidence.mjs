#!/usr/bin/env node
// Validates review evidence that an outside review engine hands to the create-pr skill, with
// Node.js only. The create-pr skill runs it on the branch; on a pass it uses the printed line
// instead of its own review, on a failure it says why and reviews as without the evidence.
//
// The file: JSON Lines, one object per line; blank lines are skipped. Three kinds:
//   {"kind":"review"|"confirm","role":"<role>","input":"plan"|"diff"|"question",
//    "provider":"<name>","model":"<model>"|null,"base":"<sha the input starts from, or empty>",
//    "head":"<HEAD sha>","dirty":true|false,"coverage":"full"|"tools"|"partial",
//    "at":"<UTC ISO 8601>"}
//     one review by a provider (review), or the narrow confirmation that the fixes of blockers
//     hold, over the diff from base to head (confirm); dirty is true when the working tree had
//     uncommitted changes to tracked files; coverage is full when the whole input was read, tools
//     when something was cut and the provider could read the repository, partial when something
//     was cut and it could not.
//   {"kind":"finding","role":"<role>","severity":"blocker"|"non-blocker","where":"<file:line>",
//    "answer":"fixed"|"declined"|"open","note":"<one line>"}
//     one answered finding.
// A line is clean when dirty is false and its coverage is full or tools; a line that is not clean
// never counts, and its provider is not printed.
//
// Pass (exit 0, one line on stdout) when every line is valid JSON of a known kind with these
// fields, and:
// - A full review is a clean line of kind review with input diff whose base is --base. The start
//   is the head of the last full review; the full reviews at the start form the start set, in
//   which a later line of a role replaces an earlier one of the same role. With --level two the
//   start set holds at least two roles.
// - From the start, the clean confirm lines after the last full review, in file order, move a
//   pointer: a confirm whose base is the pointer moves it to its head. The pointer ends at --head.
// - No finding is a blocker whose answer is open.
// The line names each provider, and its model when it has one, of the start set and of the
// confirms that moved the pointer, in order; the coverage is tools when one of those lines has
// tools, otherwise full:
//   Review: external, <provider> (<model>)[, ...], coverage <full|tools>, head <short sha>
// Fail: exit 1 and the reason on stderr. Usage errors: exit 2.
//
// Usage: scripts/check-review-evidence.mjs [--head <sha>] [--base <sha>] [--level one|two] <file>
//   --head   the commit the pull request opens at; default: git rev-parse HEAD
//   --base   the commit the change starts from; default: the base that scripts/lib/git-base.sh
//            resolves, the one scripts/check-decisions.sh compares with
//   --level  one (default) or two, the review that scripts/check-decisions.sh --classes asks for
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const usage = (why) => {
  if (why) console.error(`review evidence: ${why}`);
  console.error('usage: scripts/check-review-evidence.mjs [--head <sha>] [--base <sha>] [--level one|two] <file>');
  process.exit(2);
};
const fail = (reason) => {
  console.error(`review evidence: ${reason}`);
  process.exit(1);
};

const args = process.argv.slice(2);
const opt = {};
let file = null;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (['--head', '--base', '--level'].includes(a) && i + 1 < args.length) opt[a.slice(2)] = args[++i];
  else if (!a.startsWith('-') && file === null) file = a;
  else usage();
}
if (!file) usage();
const level = opt.level ?? 'one';
if (!['one', 'two'].includes(level)) usage(`unknown level ${level}`);

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const run = (cmd, argv, what) => {
  try {
    return execFileSync(cmd, argv, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    usage(`cannot resolve ${what}; give it`);
  }
};
const head = (opt.head ?? run('git', ['rev-parse', 'HEAD'], '--head')).toLowerCase();
const base = (opt.base ?? run('bash', ['-c', '. scripts/lib/git-base.sh && resolve_base'], '--base')).toLowerCase();
for (const [k, v] of [['head', head], ['base', base]]) if (!/^[0-9a-f]{7,64}$/.test(v)) usage(`--${k} is no commit sha: ${v}`);

let text;
try {
  text = readFileSync(file, 'utf8');
} catch (e) {
  usage(`cannot read ${file}: ${e.code ?? e.message}`);
}

const str = (v) => typeof v === 'string';
const oneOf = (...values) => (v) => values.includes(v);
const REVIEW = {
  role: str,
  input: oneOf('plan', 'diff', 'question'),
  provider: (v) => str(v) && v !== '',
  model: (v) => v === null || str(v),
  base: str,
  head: (v) => str(v) && v !== '',
  dirty: (v) => typeof v === 'boolean',
  coverage: oneOf('full', 'tools', 'partial'),
  at: str,
};
const FIELDS = {
  review: REVIEW,
  confirm: REVIEW,
  finding: {
    role: str,
    severity: oneOf('blocker', 'non-blocker'),
    where: str,
    answer: oneOf('fixed', 'declined', 'open'),
    note: str,
  },
};

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
  lines.push({ n, ...o, base: o.base?.toLowerCase(), head: o.head?.toLowerCase() });
});

const clean = (o) => o.dirty === false && (o.coverage === 'full' || o.coverage === 'tools');
const full = lines.filter((o) => o.kind === 'review' && o.input === 'diff' && clean(o) && o.base === base);
if (!full.length) fail(`no clean review of the diff from the base ${base} (kind review, input diff, dirty false, coverage full or tools)`);
const last = full[full.length - 1];
const start = last.head;
const byRole = new Map();
for (const o of full) if (o.head === start) byRole.set(o.role, o);
if (level === 'two' && byRole.size < 2) fail(`level two needs full reviews of two roles at ${start}; found ${[...byRole.keys()].join(', ')}`);

const chain = [];
let pointer = start;
for (const o of lines) {
  if (o.kind !== 'confirm' || o.n < last.n || !clean(o) || o.base !== pointer) continue;
  chain.push(o);
  pointer = o.head;
}
if (pointer !== head) fail(`the reviews end at ${pointer}, not at the head ${head}; a clean confirm from ${pointer} is missing`);

const open = lines.filter((o) => o.kind === 'finding' && o.severity === 'blocker' && o.answer === 'open');
if (open.length) fail(`open blocker: ${open.map((o) => `${o.where} (line ${o.n})`).join(', ')}`);

const counted = [...byRole.values()].sort((x, y) => x.n - y.n).concat(chain);
const names = [];
for (const o of counted) {
  const name = o.model ? `${o.provider} (${o.model})` : o.provider;
  if (!names.includes(name)) names.push(name);
}
const coverage = counted.some((o) => o.coverage === 'tools') ? 'tools' : 'full';
console.log(`Review: external, ${names.join(', ')}, coverage ${coverage}, head ${head.slice(0, 7)}`);
