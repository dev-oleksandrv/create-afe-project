#!/usr/bin/env node
// JSON for the hooks and scripts, with Node.js only.
//
// Usage: node scripts/lib/json.mjs <command> [arguments]
//   fields <path>...         read JSON from stdin; print the value at each dotted path, each
//                            followed by a NUL byte, an empty string when missing
//   get <path> [default]     read JSON from stdin; print the value at the path, or the default
//   ask <reason>             print the PreToolUse decision that asks the owner, with the reason
//   deny <reason>            print the PreToolUse decision that denies the action, with the reason
//   message <text>           print {"systemMessage": text}, a message that the user sees
//   settings [--check]       merge .claude/settings.template.json and .claude/settings.project.json
//                            into .claude/settings.json (scripts/gen-settings.sh); with --check,
//                            write nothing and exit 1 when the file is missing or stale
//   hooks                    print the command of every hook in .claude/settings.json, one per line
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const stdin = () => readFileSync(0, 'utf8');
const at = (obj, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
const text = (v) => (v == null ? '' : typeof v === 'string' ? v : JSON.stringify(v));

function parse(input) {
  try {
    return JSON.parse(input || 'null');
  } catch {
    return null;
  }
}

const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function equal(a, b) {
  if (a === b) return true;
  if (Array.isArray(a) && Array.isArray(b)) return a.length === b.length && a.every((x, i) => equal(x, b[i]));
  if (isObject(a) && isObject(b)) {
    const ka = Object.keys(a);
    return ka.length === Object.keys(b).length && ka.every((k) => k in b && equal(a[k], b[k]));
  }
  return false;
}

// Objects merge by key, arrays are a union in order without duplicates, anything else: b wins.
function merge(a, b) {
  if (isObject(a) && isObject(b)) {
    const out = {};
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      out[k] = k in a && k in b ? merge(a[k], b[k]) : k in b ? b[k] : a[k];
    }
    return out;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    const out = [];
    for (const x of [...a, ...b]) if (!out.some((y) => equal(x, y))) out.push(x);
    return out;
  }
  return b;
}

// Takes out of a what r names: keys recurse, array elements equal to one of r are removed.
function drop(a, r) {
  if (isObject(a) && isObject(r)) {
    const out = { ...a };
    for (const k of Object.keys(r)) if (k in out) out[k] = drop(out[k], r[k]);
    return out;
  }
  if (Array.isArray(a) && Array.isArray(r)) return a.filter((x) => !r.some((y) => equal(x, y)));
  return a;
}

function settings(check) {
  const read = (f) => JSON.parse(readFileSync(f, 'utf8'));
  const template = read('.claude/settings.template.json');
  const project = existsSync('.claude/settings.project.json') ? read('.claude/settings.project.json') ?? {} : {};
  const { remove = {}, ...rest } = project;
  const merged = drop(merge(template, rest), remove);
  const file = '.claude/settings.json';
  if (check) {
    if (!existsSync(file) || !equal(parse(readFileSync(file, 'utf8')), merged)) {
      console.log('FAIL: .claude/settings.json is missing or stale; run scripts/gen-settings.sh');
      process.exit(1);
    }
    return;
  }
  writeFileSync(file, `${JSON.stringify(merged, null, 2)}\n`);
}

const [command, ...args] = process.argv.slice(2);
switch (command) {
  case 'fields': {
    // @secret moved into .claude/hooks/guard.sh; fail rather than print an empty match.
    if (args.some((p) => p.startsWith('@'))) {
      console.error(`json.mjs: unknown field ${args.find((p) => p.startsWith('@'))}`);
      process.exit(2);
    }
    const data = parse(stdin());
    process.stdout.write(args.map((p) => `${text(at(data, p))}\0`).join(''));
    break;
  }
  case 'get': {
    const v = at(parse(stdin()), args[0]);
    process.stdout.write(v == null || v === '' ? (args[1] ?? '') : text(v));
    break;
  }
  case 'ask':
  case 'deny':
    process.stdout.write(
      `${JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: command, permissionDecisionReason: args[0] } })}\n`,
    );
    break;
  case 'message':
    process.stdout.write(`${JSON.stringify({ systemMessage: args[0] ?? '' })}\n`);
    break;
  case 'settings':
    settings(args[0] === '--check');
    break;
  case 'hooks': {
    const s = parse(existsSync('.claude/settings.json') ? readFileSync('.claude/settings.json', 'utf8') : '');
    const commands = Object.values(s?.hooks ?? {})
      .flat()
      .flatMap((m) => m?.hooks ?? [])
      .map((h) => h?.command)
      .filter((c) => typeof c === 'string');
    process.stdout.write(commands.map((c) => `${c.replace(/\n/g, ' ')}\n`).join(''));
    break;
  }
  default:
    console.error(`json.mjs: unknown command ${command ?? '(none)'}`);
    process.exit(2);
}
