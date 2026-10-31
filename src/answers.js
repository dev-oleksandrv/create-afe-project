// Collects the answers to the template's questions, and reads and writes the answers file that
// records them with the template version.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import * as p from '@clack/prompts';
import { parse as parseYaml } from 'yaml';
import { ANSWERS_FILE, LEGACY_ANSWERS_FILE, QUESTIONS, computed } from './config.js';

export class UsageError extends Error {}

/**
 * Turns a `--data` string into the type of its question.
 * @param {string} name
 * @param {unknown} value
 * @returns {unknown}
 */
export function coerce(name, value) {
  const q = QUESTIONS.find((x) => x.name === name);
  if (!q) throw new UsageError(`unknown question: ${name}`);
  if (q.type === 'bool' && typeof value === 'string') {
    if (/^(true|yes|y|1)$/i.test(value)) return true;
    if (/^(false|no|n|0)$/i.test(value)) return false;
    throw new UsageError(`${name}: expected true or false, got ${value}`);
  }
  if (q.type === 'choice' && !q.choices.some((c) => c.value === value)) {
    throw new UsageError(`${name}: expected one of ${q.choices.map((c) => c.value).join(', ')}`);
  }
  return value;
}

function check(q, value) {
  const error = q.validate?.(String(value));
  if (error) throw new UsageError(`${q.name}: ${error}`);
}

async function ask(q, initial) {
  let value;
  if (q.type === 'bool') {
    value = await p.confirm({ message: q.help, initialValue: initial ?? q.default });
  } else if (q.type === 'choice') {
    value = await p.select({
      message: q.help,
      options: q.choices.map((c) => ({ value: c.value, label: c.label })),
      initialValue: initial ?? q.default,
    });
  } else {
    const start = initial ?? q.default;
    value = await p.text({
      message: q.help,
      initialValue: start,
      placeholder: start,
      validate: (v) => q.validate?.(v ?? ''),
    });
  }
  if (p.isCancel(value)) {
    p.cancel('Cancelled; nothing was written.');
    process.exit(130);
  }
  return value;
}

/**
 * Answers every question in order. A value from `given` is taken without asking; then, with
 * `useDefaults`, the previous answer or the question's default; a question with neither is asked,
 * or fails when `interactive` is false. A question whose `when` is false is not answered.
 * @param {{ given?: Record<string, unknown>, previous?: Record<string, unknown>,
 *   useDefaults?: boolean, interactive?: boolean }} options
 * @returns {Promise<{ answers: Record<string, unknown>, context: Record<string, unknown> }>}
 *   the answers to record, and the rendering context with every question and computed value
 */
export async function collectAnswers({ given = {}, previous = {}, useDefaults = false, interactive = true }) {
  for (const name of Object.keys(given)) coerce(name, given[name]);
  const answers = {};
  const context = {};
  for (const q of QUESTIONS) {
    if (q.when && !q.when(context)) {
      context[q.name] = q.default ?? '';
      continue;
    }
    let value;
    if (q.name in given) {
      value = coerce(q.name, given[q.name]);
    } else if (useDefaults && (q.name in previous || 'default' in q)) {
      value = q.name in previous ? previous[q.name] : q.default;
    } else if (interactive) {
      value = await ask(q, previous[q.name]);
    } else {
      throw new UsageError(`${q.name} has no answer; pass --data ${q.name}=<value> or run in a terminal`);
    }
    check(q, value);
    answers[q.name] = value;
    context[q.name] = value;
  }
  return { answers, context: { ...context, ...computed(context) } };
}

/**
 * Reads the recorded answers of a project: the answers file, or a Copier answers file of a project
 * generated before the template moved to npm.
 * @param {string} dir
 * @returns {{ version: string | null, answers: Record<string, unknown>, legacy: boolean } | null}
 */
export function readAnswers(dir) {
  const file = join(dir, ANSWERS_FILE);
  if (existsSync(file)) {
    const { _version = null, ...rest } = JSON.parse(readFileSync(file, 'utf8'));
    return { version: _version, answers: strip(rest), legacy: false };
  }
  const legacy = join(dir, LEGACY_ANSWERS_FILE);
  if (existsSync(legacy)) {
    const data = parseYaml(readFileSync(legacy, 'utf8')) ?? {};
    const commit = typeof data._commit === 'string' ? data._commit.replace(/^v/, '').split('-')[0] : null;
    return { version: commit, answers: strip(data), legacy: true };
  }
  return null;
}

function strip(data) {
  return Object.fromEntries(Object.entries(data).filter(([k]) => !k.startsWith('_')));
}

/**
 * @param {string} dir
 * @param {string} version
 * @param {Record<string, unknown>} answers
 */
export function writeAnswers(dir, version, answers) {
  const data = {
    _note: 'Written by create-afe-project; never edit by hand (docs/documentation-rules.md, section 9).',
    _version: version,
    ...answers,
  };
  writeFileSync(join(dir, ANSWERS_FILE), `${JSON.stringify(data, null, 2)}\n`);
}

/**
 * Compares two versions MAJOR.MINOR.PATCH; a missing version is the lowest.
 * @param {string | null} a
 * @param {string | null} b
 * @returns {number}
 */
export function compareVersions(a, b) {
  const parts = (v) => (v ?? '0.0.0').split('.').map((n) => Number.parseInt(n, 10) || 0);
  const [x, y] = [parts(a), parts(b)];
  for (let i = 0; i < 3; i += 1) if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
  return 0;
}
