// Creates a project from the template, and updates a project to the template of this package.
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { UsageError, collectAnswers, compareVersions, readAnswers, writeAnswers } from './answers.js';
import { LEGACY_ANSWERS_FILE, MIGRATIONS, SEEDED, TASKS, messageAfterCreate } from './config.js';
import { renderTemplate } from './render.js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const TEMPLATE_DIR = join(ROOT, 'template');
export const VERSION = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')).version;

const OWNED_LIST = '.template/owned.txt';
const MANIFEST = '.template/owned.sha256';
const START = '<!-- project:start -->';
const END = '<!-- project:end -->';

function writeFile(dir, rel, { content, mode }) {
  const target = join(dir, rel);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, content);
  chmodSync(target, mode & 0o777);
}

function run(dir, command, quiet) {
  const r = spawnSync('bash', ['-c', command], {
    cwd: dir,
    stdio: ['ignore', quiet ? 'pipe' : 'inherit', quiet ? 'pipe' : 'inherit'],
    encoding: 'utf8',
  });
  if (r.status !== 0) {
    const output = quiet ? `\n${r.stdout ?? ''}${r.stderr ?? ''}` : '';
    throw new Error(`\`${command}\` failed with exit code ${r.status}${output}`);
  }
}

function runTasks(dir, quiet) {
  for (const task of TASKS) run(dir, task, quiet);
}

function listed(text) {
  return text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

/** Lines of AGENTS.md inside its project block; throws unless there is exactly one. */
function projectBlock(text) {
  const lines = text.split('\n');
  const s = lines.filter((l) => l === START).length;
  const e = lines.filter((l) => l === END).length;
  const si = lines.indexOf(START);
  const ei = lines.indexOf(END);
  if (s !== 1 || e !== 1 || si > ei) {
    throw new UsageError(`AGENTS.md needs exactly one '${START}' line followed by one '${END}' line`);
  }
  return lines.slice(si + 1, ei);
}

function withBlock(rendered, block) {
  const lines = rendered.split('\n');
  const si = lines.indexOf(START);
  const ei = lines.indexOf(END);
  return [...lines.slice(0, si + 1), ...block, ...lines.slice(ei)].join('\n');
}

/** The content that the manifest hash covers, as scripts/check-template.sh computes it. */
function hashed(rel, text) {
  if (rel !== 'AGENTS.md') return text;
  let skip = false;
  const kept = [];
  for (const line of text.split('\n')) {
    if (line === START) {
      kept.push(line);
      skip = true;
    } else if (line === END) {
      skip = false;
      kept.push(line);
    } else if (!skip) kept.push(line);
  }
  return kept.join('\n');
}

const sha256 = (text) => createHash('sha256').update(text).digest('hex');

/** Template-owned files whose content no longer matches the recorded manifest. */
function editedOwnedFiles(dir) {
  const manifest = join(dir, MANIFEST);
  if (!existsSync(manifest)) return [];
  const edited = [];
  for (const line of listed(readFileSync(manifest, 'utf8'))) {
    const [hash, rel] = line.split(/\s+/, 2);
    const file = join(dir, rel);
    if (existsSync(file) && sha256(hashed(rel, readFileSync(file, 'utf8'))) !== hash) edited.push(rel);
  }
  return edited;
}

function isDirty(dir) {
  try {
    return execFileSync('git', ['status', '--porcelain'], { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() !== '';
  } catch {
    return false; // not a Git repository
  }
}

/**
 * Creates a project in `dir`.
 * @param {string} dir
 * @param {{ given?: Record<string, unknown>, useDefaults?: boolean, interactive?: boolean,
 *   force?: boolean, quiet?: boolean, log?: (msg: string) => void }} options
 * @returns {Promise<{ answers: Record<string, unknown>, message: string }>}
 */
export async function create(dir, { given, useDefaults, interactive, force = false, quiet = false, git = true, log = () => {} }) {
  const empty = !existsSync(dir) || readdirSync(dir).every((n) => n === '.git');
  if (!empty && !force) {
    throw new UsageError(`${dir} is not empty; choose an empty directory, or pass --force to write into it`);
  }
  const { answers, context } = await collectAnswers({ given, useDefaults, interactive });
  mkdirSync(dir, { recursive: true });
  for (const [rel, file] of renderTemplate(TEMPLATE_DIR, context)) writeFile(dir, rel, file);
  writeAnswers(dir, VERSION, answers);
  log('Writing generated files');
  runTasks(dir, quiet);
  let commit = { done: false, reason: 'skipped with --no-git' };
  if (git) {
    log('Making the initial commit');
    commit = empty ? initialCommit(dir) : { done: false, reason: 'the directory was not empty' };
  }
  return { answers, commit, message: messageAfterCreate(answers, commit) };
}

/**
 * Commits the generated files as the first commit on `main`: the one direct commit to `main` that
 * docs/contributing.md, section 1, allows. Runs only in a new repository, or in one without
 * commits (an empty clone); never throws.
 * @param {string} dir
 * @returns {{ done: boolean, reason?: string }}
 */
export function initialCommit(dir) {
  const git = (...args) => spawnSync('git', args, { cwd: dir, encoding: 'utf8' });
  const failed = (r) => r.error || r.status !== 0;
  const why = (r) => (r.error ? r.error.message : (r.stderr || r.stdout || '').trim().split('\n')[0]);
  if (existsSync(join(dir, '.git'))) {
    if (!failed(git('rev-parse', '--verify', '--quiet', 'HEAD'))) return { done: false, reason: 'the repository already has commits' };
    const r = git('symbolic-ref', 'HEAD', 'refs/heads/main');
    if (failed(r)) return { done: false, reason: why(r) };
  } else {
    const r = git('init', '--quiet', '--initial-branch=main');
    if (failed(r)) return { done: false, reason: `git init failed: ${why(r)}` };
  }
  for (const args of [['add', '--all'], ['commit', '--quiet', '-m', `Template: create the project with create-afe-project ${VERSION}`]]) {
    const r = git(...args);
    if (failed(r)) return { done: false, reason: `git ${args[0]} failed: ${why(r)}` };
  }
  return { done: true };
}

/**
 * Updates the project in `dir` to this package's template. Template-owned files are replaced, the
 * project block of AGENTS.md is kept, files the template no longer owns are removed, missing
 * seeded files are created and existing ones never changed, the migrations between the two
 * versions run, and the generated files are rebuilt.
 * @param {string} dir
 * @param {{ given?: Record<string, unknown>, useDefaults?: boolean, interactive?: boolean,
 *   allowDirty?: boolean, quiet?: boolean }} options
 */
export async function update(dir, { given, useDefaults, interactive, allowDirty = false, quiet = false }) {
  const recorded = readAnswers(dir);
  if (!recorded) throw new UsageError(`${dir} has no answers file; is it a project created by create-afe-project?`);
  if (compareVersions(recorded.version, VERSION) > 0) {
    throw new UsageError(`the project follows template ${recorded.version}, newer than this package (${VERSION}); run npx create-afe-project@latest update`);
  }
  if (!allowDirty && isDirty(dir)) {
    throw new UsageError('the working tree has uncommitted changes; commit or stash them, or pass --allow-dirty');
  }
  const agentsFile = join(dir, 'AGENTS.md');
  const block = existsSync(agentsFile) ? projectBlock(readFileSync(agentsFile, 'utf8')) : null;

  const { answers, context } = await collectAnswers({ given, previous: recorded.answers, useDefaults, interactive });
  const rendered = renderTemplate(TEMPLATE_DIR, context);
  const newOwned = listed(String(rendered.get(OWNED_LIST).content));
  const oldOwnedFile = join(dir, OWNED_LIST);
  const oldOwned = existsSync(oldOwnedFile) ? listed(readFileSync(oldOwnedFile, 'utf8')) : [];
  const edited = editedOwnedFiles(dir);
  const pending = MIGRATIONS.filter(
    (m) => compareVersions(m.version, recorded.version) > 0 && compareVersions(m.version, VERSION) <= 0,
  );

  for (const m of pending) if (m.before) run(dir, m.before, quiet);

  const removed = oldOwned.filter((rel) => !newOwned.includes(rel) && existsSync(join(dir, rel)));
  for (const rel of removed) rmSync(join(dir, rel));

  const seeded = [];
  const unowned = [];
  for (const [rel, file] of rendered) {
    const exists = existsSync(join(dir, rel));
    if (newOwned.includes(rel)) {
      const content = rel === 'AGENTS.md' && block ? withBlock(String(file.content), block) : file.content;
      writeFile(dir, rel, { ...file, content });
    } else if (!exists) {
      writeFile(dir, rel, file);
      (SEEDED.includes(rel) ? seeded : unowned).push(rel);
    }
  }
  writeAnswers(dir, VERSION, answers);
  if (recorded.legacy) rmSync(join(dir, LEGACY_ANSWERS_FILE));

  for (const m of pending) if (m.after) run(dir, m.after, quiet);
  runTasks(dir, quiet);

  return { from: recorded.version, to: VERSION, removed, edited, seeded, unowned, migrations: pending.map((m) => m.version), legacy: recorded.legacy };
}
