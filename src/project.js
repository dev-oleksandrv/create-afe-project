// Creates a project from the template, and updates a project to the template of this package.
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  closeSync, constants, existsSync, fchmodSync, lstatSync, mkdirSync, mkdtempSync, openSync, readdirSync, readFileSync,
  rmSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, isAbsolute, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { UsageError, collectAnswers, compareVersions, readAnswers, writeAnswers } from './answers.js';
import { ANSWERS_FILE, MIGRATIONS, QUESTIONS, SEEDED, TASKS, messageAfterCreate } from './config.js';
import { renderTemplate } from './render.js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const TEMPLATE_DIR = join(ROOT, 'template');
export const VERSION = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')).version;

const OWNED_LIST = '.template/owned.txt';
const MANIFEST = '.template/owned.sha256';
const START = '<!-- project:start -->';
const END = '<!-- project:end -->';

/**
 * Checks a path that create or update reads, writes, or removes: relative, with no empty, `.`, or
 * `..` component and no backslash, and with no symbolic link, and no file where a directory is
 * expected, among its existing components, so that it stays inside `dir` and nothing follows a
 * link. With `link`, the path itself may be a symbolic link, for a path that is left as it is.
 * @param {string} dir
 * @param {string} rel
 * @param {{ link?: boolean }} [options]
 * @returns {import('node:fs').Stats | null} the lstat of the path, or null when it does not exist
 * @throws {Error} naming the reason
 */
export function checkPath(dir, rel, { link = false } = {}) {
  const parts = rel.split('/');
  if (isAbsolute(rel) || rel.includes('\\') || parts.some((c) => c === '' || c === '.' || c === '..')) {
    throw new Error('is not a relative path inside the project');
  }
  for (let i = 0; i < parts.length; i += 1) {
    const at = parts.slice(0, i + 1).join('/');
    let stat;
    try {
      stat = lstatSync(join(dir, at));
    } catch (error) {
      if (error.code === 'ENOENT') return null;
      throw error;
    }
    const last = i === parts.length - 1;
    if (stat.isSymbolicLink() && !(last && link)) {
      throw new Error(last ? `is the symbolic link ${at}` : `goes through the symbolic link ${at}`);
    }
    if (last) return stat;
    if (!stat.isDirectory()) throw new Error(`needs a directory where ${at} is not a directory`);
  }
  return null;
}

/**
 * Throws a UsageError unless `rel` passes checkPath and is a regular file or nothing; with `kept`,
 * a path the update leaves as it is when it exists, anything there passes. `what` begins the
 * message.
 */
function checkFile(dir, rel, what, { kept = false } = {}) {
  let stat;
  try {
    stat = checkPath(dir, rel, { link: kept });
  } catch (error) {
    throw new UsageError(`${what} ${JSON.stringify(rel)}, which ${error.message}; nothing was changed`);
  }
  if (stat && !kept && !stat.isFile()) throw new UsageError(`${what} ${JSON.stringify(rel)}, which is not a regular file; nothing was changed`);
  return stat;
}

/**
 * Removes the directories of `rel` that are left empty, from its own directory up, and stops below
 * the project root `dir`, whatever `rel` holds.
 * @param {string} dir
 * @param {string} rel
 */
export function pruneEmptyDirs(dir, rel) {
  const root = resolve(dir);
  for (let d = resolve(root, dirname(rel)); d.startsWith(root + sep) && readdirSync(d).length === 0; d = dirname(d)) {
    rmSync(d, { recursive: true });
  }
}

// Opens with O_NOFOLLOW, so that a symbolic link at the target is never written or changed in mode.
function writeFile(dir, rel, { content, mode }) {
  const target = join(dir, rel);
  mkdirSync(dirname(target), { recursive: true });
  const fd = openSync(target, constants.O_WRONLY | constants.O_CREAT | constants.O_TRUNC | (constants.O_NOFOLLOW ?? 0), 0o644);
  try {
    writeFileSync(fd, content);
    fchmodSync(fd, mode & 0o777);
  } finally {
    closeSync(fd);
  }
}

function run(dir, command, quiet, env) {
  const r = spawnSync('bash', ['-c', command], {
    cwd: dir,
    env: env ? { ...process.env, ...env } : process.env,
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

/** The SHA-256 that scripts/check-template.sh records for a template-owned file of this content. */
function ownedHash(rel, content) {
  let data = content;
  if (rel === 'AGENTS.md') {
    // As its awk: AGENTS.md without the lines inside its project block, each line ending in a newline.
    const lines = String(content).split('\n');
    if (lines.at(-1) === '') lines.pop();
    let skip = false;
    const kept = [];
    for (const line of lines) {
      if (line === START) {
        kept.push(line);
        skip = true;
        continue;
      }
      if (line === END) skip = false;
      if (!skip) kept.push(line);
    }
    data = kept.map((l) => `${l}\n`).join('');
  }
  return createHash('sha256').update(data).digest('hex');
}

function isDirty(dir) {
  try {
    return execFileSync('git', ['status', '--porcelain'], { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() !== '';
  } catch {
    return false; // not a Git repository
  }
}

/**
 * Creates a project in `dir`. Before it writes anything, it checks every path it writes
 * (checkPath), so that a directory given with --force has no symbolic link on the way.
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
  const rendered = renderTemplate(TEMPLATE_DIR, context);
  for (const rel of [...rendered.keys(), ANSWERS_FILE]) checkFile(dir, rel, 'the template writes');
  mkdirSync(dir, { recursive: true });
  for (const [rel, file] of rendered) writeFile(dir, rel, file);
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
 * the rules allow. Runs only in a new repository, or in one without commits (an empty clone);
 * never throws.
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
 * seeded files are created and existing ones changed only by a migration, the migrations between the two
 * versions run, and the generated files are rebuilt. The result names, besides the files, the
 * recorded answers that are dropped, since no question takes them, and notes: what is left to do by
 * hand.
 *
 * Before it changes anything, it checks every path it reads, writes, or removes (checkPath): a bad
 * entry of .template/owned.txt or .template/owned.sha256 stops it with a UsageError that names the
 * entry. Then it passes `confirm` the template-owned files with local edits that it replaces or
 * removes (by .template/owned.sha256) and the files it removes; when `confirm` resolves false, it
 * changes nothing and returns `{ cancelled: true }`. The new version is recorded last, after the
 * migrations and the tasks: an update that fails part way keeps the recorded version, so the next
 * run runs the same migrations again.
 * @param {string} dir
 * @param {{ given?: Record<string, unknown>, useDefaults?: boolean, interactive?: boolean,
 *   allowDirty?: boolean, quiet?: boolean,
 *   confirm?: (preview: { edited: string[], removed: string[], manifest?: 'missing' }) => Promise<boolean> }} options
 */
export async function update(dir, { given, useDefaults, interactive, allowDirty = false, quiet = false, confirm = async () => true }) {
  checkFile(dir, ANSWERS_FILE, 'the update reads and writes');
  const recorded = readAnswers(dir);
  if (!recorded) throw new UsageError(`${dir} has no answers file; is it a project created by create-afe-project?`);
  if (compareVersions(recorded.version, VERSION) > 0) {
    throw new UsageError(`the project follows template ${recorded.version}, newer than this package (${VERSION}); run npx create-afe-project@latest update`);
  }
  if (!allowDirty && isDirty(dir)) {
    throw new UsageError('the working tree has uncommitted changes; commit or stash them, or pass --allow-dirty');
  }
  const read = (rel) => (checkFile(dir, rel, 'the update reads') ? readFileSync(join(dir, rel), 'utf8') : null);
  const oldOwned = listed(read(OWNED_LIST) ?? '');
  const stats = new Map(oldOwned.map((rel) => [rel, checkFile(dir, rel, `${OWNED_LIST} lists`)]));
  const recordedHashes = new Map();
  const manifest = read(MANIFEST);
  for (const line of listed(manifest ?? '')) {
    const [, hash, rel] = /^(\S+)\s+(.+)$/.exec(line) ?? [];
    if (!rel) throw new UsageError(`${MANIFEST} has the line ${JSON.stringify(line)}, which is not a hash and a path; nothing was changed`);
    stats.set(rel, checkFile(dir, rel, `${MANIFEST} lists`));
    recordedHashes.set(rel, hash);
  }
  const agents = read('AGENTS.md');
  const block = agents === null ? null : projectBlock(agents);

  const { answers, context } = await collectAnswers({ given, previous: recorded.answers, useDefaults, interactive });
  const rendered = renderTemplate(TEMPLATE_DIR, context);
  const newOwned = listed(String(rendered.get(OWNED_LIST).content));
  const content = (rel) => (rel === 'AGENTS.md' && block ? withBlock(String(rendered.get(rel).content), block) : rendered.get(rel).content);
  for (const rel of newOwned) stats.set(rel, checkFile(dir, rel, 'the template writes'));
  // A seeded file is written only when it is missing; an existing one, a symbolic link too, stays.
  for (const rel of rendered.keys()) if (!stats.has(rel)) stats.set(rel, checkFile(dir, rel, 'the template writes', { kept: true }));

  const removed = oldOwned.filter((rel) => !newOwned.includes(rel) && stats.get(rel));
  // Local edits: a template-owned file whose hash is not the recorded one, which the update removes,
  // or whose content it changes. An edit that a failed update already replaced is none.
  const edited = [...recordedHashes].filter(([rel, hash]) => {
    if (!stats.get(rel) || !(removed.includes(rel) || newOwned.includes(rel))) return false;
    const current = readFileSync(join(dir, rel));
    return ownedHash(rel, current) !== hash && (removed.includes(rel) || !current.equals(Buffer.from(content(rel))));
  }).map(([rel]) => rel);
  const preview = manifest === null && oldOwned.length ? { edited, removed, manifest: 'missing' } : { edited, removed };
  if ((edited.length || removed.length || preview.manifest) && !(await confirm(preview))) return { cancelled: true };

  // Recorded answers without a question here are dropped: those of a question removed since, such
  // as docs_review in 3.0.0.
  const dropped = Object.keys(recorded.answers).filter((k) => !QUESTIONS.some((q) => q.name === k));
  const notes = [];
  const pending = MIGRATIONS.filter(
    (m) => compareVersions(m.version, recorded.version) > 0 && compareVersions(m.version, VERSION) <= 0,
  );
  // A migration appends what is left to do by hand, one line each, to the file AFE_NOTES.
  const scratch = mkdtempSync(join(tmpdir(), 'afe-update-'));
  const env = { AFE_TEMPLATE: TEMPLATE_DIR, AFE_NOTES: join(scratch, 'notes') };
  const seeded = [];
  const unowned = [];
  try {
    for (const m of pending) if (m.before) run(dir, m.before, quiet, env);

    for (const rel of removed) {
      checkPath(dir, rel);
      rmSync(join(dir, rel));
      // A directory left empty, such as the one of a removed skill, goes with its last file.
      pruneEmptyDirs(dir, rel);
    }

    for (const [rel, file] of rendered) {
      // Checked again: a `before` migration ran in the project since.
      if (newOwned.includes(rel)) {
        checkPath(dir, rel);
        writeFile(dir, rel, { ...file, content: content(rel) });
      } else {
        if (checkPath(dir, rel, { link: true })) continue;
        writeFile(dir, rel, file);
        (SEEDED.includes(rel) ? seeded : unowned).push(rel);
      }
    }

    for (const m of pending) if (m.after) run(dir, m.after, quiet, env);
    if (existsSync(env.AFE_NOTES)) notes.push(...listed(readFileSync(env.AFE_NOTES, 'utf8')));
    runTasks(dir, quiet);
    writeAnswers(dir, VERSION, answers);
  } catch (error) {
    throw new Error(
      `${error.message}\nThe update stopped before it finished: the project still records template ${recorded.version ?? 'no version'}, ` +
        'and the files changed so far are not committed. Fix the cause, then run the same update again with --allow-dirty, ' +
        'which runs the migrations again; or discard the changes with Git.',
    );
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }

  return {
    from: recorded.version, to: VERSION, removed, edited, seeded, unowned,
    migrations: pending.map((m) => m.version), dropped, notes,
  };
}
