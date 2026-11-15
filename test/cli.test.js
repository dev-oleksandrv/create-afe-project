// Unit tests of the CLI's parts; the end-to-end tests of create and update are in
// test/template/, run by scripts/checks.d/10-template.sh (docs/maintaining.md, section 3).
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdtempSync, mkdirSync, readdirSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { UsageError, coerce, collectAnswers, compareVersions, readAnswers } from '../src/answers.js';
import { MIGRATIONS, SEEDED, messageAfterCreate } from '../src/config.js';
import * as project from '../src/project.js';
import { renderString, renderTemplate } from '../src/render.js';

const { TEMPLATE_DIR } = project;

const base = { project_name: 'sample', project_description: 'A sample.', github_repo: 'o/sample' };
const answer = (given) => collectAnswers({ given: { ...base, ...given }, useDefaults: true, interactive: false });

test('questions take their defaults and skip the runner labels on a GitHub-hosted runner', async () => {
  const { answers, context } = await answer({});
  assert.deepEqual(Object.keys(answers), [
    'project_name', 'project_description', 'github_repo', 'ci_runner', 'code_review', 'secret_scan',
    'acceptance_check', 'fail_without_change',
  ]);
  assert.equal(context.ci_runs_on_default, '["ubuntu-latest"]');
});

test('code review in CI is off and the acceptance check on by default; the removed review modules are no questions', async () => {
  const { answers } = await answer({});
  assert.equal(answers.code_review, false);
  assert.equal(answers.acceptance_check, true);
  assert.equal(answers.secret_scan, true);
  assert.equal(answers.fail_without_change, false);
  for (const name of ['docs_review', 'dual_review']) assert.throws(() => coerce(name, 'true'), new RegExp(`unknown question: ${name}`));
});

test('a project created with the defaults has check.yml and no docs-review or dual-review files', async () => {
  const { context } = await answer({});
  const paths = [...renderTemplate(TEMPLATE_DIR, context).keys()];
  assert.ok(paths.includes('.github/workflows/check.yml'));
  assert.ok(!paths.includes('.github/workflows/docs.yml'));
  assert.deepEqual(paths.filter((p) => /docs-review|dual-review/.test(p)), []);
});

test('a self-hosted runner asks for its labels and runs on them', async () => {
  const { answers, context } = await answer({ ci_runner: 'self-hosted', self_hosted_labels: '["self-hosted", "linux"]' });
  assert.equal(answers.self_hosted_labels, '["self-hosted", "linux"]');
  assert.equal(context.ci_runs_on_default, '["self-hosted", "linux"]');
});

test('validators reject what copier.yml rejected', async () => {
  await assert.rejects(answer({ project_name: ' ' }), /project_name: Required/);
  await assert.rejects(answer({ project_description: 'No period' }), /End the sentence with a period/);
  await assert.rejects(answer({ github_repo: 'no-slash' }), /owner\/name/);
  await assert.rejects(answer({ ci_runner: 'self-hosted', self_hosted_labels: 'self-hosted' }), /JSON array/);
  await assert.rejects(answer({ ci_runner: 'cloud' }), /expected one of github-hosted, self-hosted/);
});

test('--data strings become booleans, and unknown questions fail', () => {
  assert.equal(coerce('code_review', 'false'), false);
  assert.equal(coerce('code_review', 'yes'), true);
  assert.throws(() => coerce('code_review', 'maybe'), UsageError);
  assert.throws(() => coerce('nope', 'x'), /unknown question: nope/);
});

test('without a terminal a question with no answer fails instead of hanging', async () => {
  await assert.rejects(collectAnswers({ given: {}, useDefaults: true, interactive: false }), /project_name has no answer/);
});

test('recorded answers win over defaults on an update, and answers without a question are dropped', async () => {
  const previous = { ...base, code_review: true, acceptance_check: false, docs_review: true, dual_review: false };
  const { answers } = await collectAnswers({ previous, useDefaults: true, interactive: false });
  assert.equal(answers.code_review, true);
  assert.equal(answers.acceptance_check, false);
  assert.ok(!('docs_review' in answers) && !('dual_review' in answers));
});

test('a given answer to a removed question, such as from a 2.x answers file as --data-file, is ignored', async () => {
  const { answers } = await answer({ docs_review: true, dual_review: 'false', code_review: true });
  assert.equal(answers.code_review, true);
  assert.ok(!('docs_review' in answers) && !('dual_review' in answers));
  await assert.rejects(answer({ docs_reviews: true }), /unknown question: docs_reviews/);
});

test('versions compare numerically, a missing one lowest', () => {
  assert.equal(compareVersions('0.10.0', '0.9.9'), 1);
  assert.equal(compareVersions('1.0.0', '1.0.0'), 0);
  assert.equal(compareVersions(null, '0.0.1'), -1);
});

test('Jinja syntax renders as Copier did', () => {
  assert.equal(renderString("{{ '${{' }} x {{ '}}' }}", {}), '${{ x }}');
  assert.equal(renderString('a\n{%- if x %}\nb\n{%- endif %}\n', { x: true }), 'a\nb\n');
  assert.equal(renderString('{% if x and not y %}1{% else %}2{% endif %}', { x: true, y: false }), '1');
});

test('conditional names drop files and directories, .jinja is stripped, _gitignore is renamed', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  mkdirSync(join(dir, '{% if on %}kept{% endif %}'));
  mkdirSync(join(dir, '{% if off %}dropped{% endif %}'));
  writeFileSync(join(dir, '{% if on %}kept{% endif %}', 'a.md.jinja'), '{{ name }}\n');
  writeFileSync(join(dir, '{% if off %}dropped{% endif %}', 'b.md'), 'b');
  writeFileSync(join(dir, '{% if off %}c.yml{% endif %}.jinja'), 'c');
  writeFileSync(join(dir, 'raw.sh'), '{{ name }}');
  writeFileSync(join(dir, '_gitignore'), 'node_modules/\n');
  const out = renderTemplate(dir, { on: true, off: false, name: 'x' });
  assert.deepEqual([...out.keys()].sort(), ['.gitignore', 'kept/a.md', 'raw.sh']);
  assert.equal(out.get('kept/a.md').content, 'x\n');
  assert.equal(String(out.get('raw.sh').content), '{{ name }}');
});

test('every rendered file is template-owned or seeded, with every module on and off', async () => {
  for (const on of [true, false]) {
    const flags = Object.fromEntries(['code_review', 'secret_scan', 'acceptance_check', 'fail_without_change'].map((k) => [k, on]));
    const { context } = await answer(flags);
    const out = renderTemplate(TEMPLATE_DIR, context);
    const owned = String(out.get('.template/owned.txt').content).split('\n').filter((l) => l && !l.startsWith('#'));
    const stray = [...out.keys()].filter((p) => !owned.includes(p) && !SEEDED.includes(p));
    assert.deepEqual(stray, []);
    assert.deepEqual(owned.filter((p) => !out.has(p)), [], 'owned.txt lists a file the template does not render');
  }
});

test('the answers file is read with its version, without private keys; a Copier answers file is not read', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  writeFileSync(join(dir, '.copier-answers.yml'), '_commit: v0.6.0\nproject_name: s\n');
  assert.equal(readAnswers(dir), null);
  writeFileSync(join(dir, '.afe-answers.json'), JSON.stringify({ _note: 'n', _version: '0.7.0', project_name: 't' }));
  assert.deepEqual(readAnswers(dir), { version: '0.7.0', answers: { project_name: 't' } });
});

test('the message after create numbers the next steps and says whether the initial commit was made', () => {
  const a = { project_name: 'sample', code_review: false };
  const done = messageAfterCreate(a, { done: true });
  assert.match(done, /^sample is ready\. Next:\n {2}1\. the generated files are committed on main\n/);
  assert.match(done, /\d+\. run \/afe-init in Claude Code/);
  assert.match(done, /\d+\. protect main and apply the repository settings with scripts\/protect-branch\.sh \(merge commits only, head branches deleted, secret scanning/);
  assert.doesNotMatch(done, /turn on secret scanning/);
  assert.match(messageAfterCreate(a, { done: false, reason: 'skipped with --no-git' }), /1\. commit the generated files on main .*skipped with --no-git/);
  assert.doesNotMatch(done, /CLAUDE_CODE_OAUTH_TOKEN/);
  assert.match(messageAfterCreate({ ...a, code_review: true }, { done: true }), /\d+\. add the CLAUDE_CODE_OAUTH_TOKEN secret and install the Claude GitHub App/);
});

// Runs the `after` command of the migration of `version` in `dir`, as an update does.
function migrate(version, dir, notes) {
  const m = MIGRATIONS.find((x) => x.version === version);
  assert.ok(m?.after, `MIGRATIONS has no after command for ${version}`);
  return spawnSync('bash', ['-c', m.after], {
    cwd: dir, encoding: 'utf8', env: { ...process.env, AFE_TEMPLATE: TEMPLATE_DIR, AFE_NOTES: notes },
  });
}

test('a path the update acts on is relative, plain, and has no symbolic link on the way', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  mkdirSync(join(dir, 'a'));
  writeFileSync(join(dir, 'f'), 'x');
  assert.equal(project.checkPath(dir, 'a/new.txt'), null);
  assert.ok(project.checkPath(dir, 'f').isFile());
  for (const rel of ['', '/etc/passwd', 'a//b', './a', 'a/./b', 'a/../b', '../x', 'a/', 'a\\..\\x']) {
    assert.throws(() => project.checkPath(dir, rel), /not a relative path inside the project/, rel);
  }
  assert.throws(() => project.checkPath(dir, 'f/g'), /f is not a directory/);
  symlinkSync(join(dir, 'a'), join(dir, 'l'));
  assert.throws(() => project.checkPath(dir, 'l/x'), /symbolic link l/);
  assert.throws(() => project.checkPath(dir, 'l'), /symbolic link l/);
});

test('the directories a removed file leaves empty go, up to and without the project root', () => {
  const outer = mkdtempSync(join(tmpdir(), 'afe-'));
  const dir = join(outer, 'p');
  mkdirSync(join(dir, 'a', 'b'), { recursive: true });
  project.pruneEmptyDirs(dir, 'a/b/gone.txt');
  assert.ok(existsSync(dir), 'the project root is removed');
  assert.ok(!existsSync(join(dir, 'a')), 'an empty directory is kept');
  mkdirSync(join(outer, 'x'));
  project.pruneEmptyDirs(dir, '../x/gone.txt');
  assert.ok(existsSync(join(outer, 'x')), 'a directory outside the project is removed');
});

test('a failing command fails the 3.0.0 migration', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  mkdirSync(join(dir, 'docs'));
  writeFileSync(join(dir, 'docs', 'README.md'), '# Documentation map\n');
  // The note about docs/README.md cannot be written: the directory of the notes file is missing.
  const r = migrate('3.0.0', dir, join(dir, 'missing', 'notes'));
  assert.notEqual(r.status, 0, 'the migration succeeds although writing its note failed');
});

test('the 4.0.0 migration reports the steps by hand that apply, changes nothing, and says the same on a second run', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  const notes = join(mkdtempSync(join(tmpdir(), 'afe-')), 'notes');
  mkdirSync(join(dir, '.claude', 'hooks', 'project', 'stop'), { recursive: true });
  const conf = 'SETUP=make setup\nFWC_INSTALL=npm ci\nFWC_CLASSIFIER=\nFWC_TEST=npm test\n';
  writeFileSync(join(dir, '.claude', 'harness.conf'), conf);
  writeFileSync(join(dir, '.claude', 'hooks', 'project', 'stop', '10-lint.sh'), '#!/usr/bin/env bash\n');
  writeFileSync(join(dir, '.claude', 'hooks', 'project', 'stop', '20-own.sh'), '#!/usr/bin/env bash\n');
  const settings = JSON.stringify({ hooks: { Stop: [{ hooks: [{ type: 'command', command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/project/stop/20-own.sh' }] }] } });
  writeFileSync(join(dir, '.claude', 'settings.project.json'), settings);
  const expected = [
    '.claude/harness.conf sets FWC_INSTALL, FWC_CLASSIFIER, which 4.0.0 no longer reads: delete them; the fail-without-change driver installs with SETUP',
    '.claude/hooks/project/stop/10-lint.sh no longer runs: since 4.0.0 the Stop dispatcher does not run .claude/hooks/project/stop/, so register it under hooks.Stop in .claude/settings.project.json',
  ];
  for (const run of [1, 2]) {
    const r = migrate('4.0.0', dir, notes);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(readFileSync(notes, 'utf8').trimEnd().split('\n'), [].concat(...Array(run).fill(expected)));
  }
  assert.equal(readFileSync(join(dir, '.claude', 'harness.conf'), 'utf8'), conf);
  assert.equal(readFileSync(join(dir, '.claude', 'settings.project.json'), 'utf8'), settings);

  const clean = mkdtempSync(join(tmpdir(), 'afe-'));
  mkdirSync(join(clean, '.claude'));
  writeFileSync(join(clean, '.claude', 'harness.conf'), 'SETUP=\nFWC_TEST=\n');
  const none = join(clean, 'notes');
  assert.equal(migrate('4.0.0', clean, none).status, 0);
  assert.ok(!existsSync(none) || readFileSync(none, 'utf8') === '', 'a project without the 3.x leftovers gets a note');
});

test('update shows the local edits it replaces, in the order of the manifest, and the files it removes first; a refusal changes nothing', async () => {
  const dir = join(mkdtempSync(join(tmpdir(), 'afe-')), 'p');
  await project.create(dir, { given: base, useDefaults: true, interactive: false, quiet: true, git: false });
  const docs = join(dir, '.claude', 'rules', 'docs.md');
  appendFileSync(docs, 'A local edit.\n');
  // An old manifest that lists a file this template does not own: the update removes it.
  appendFileSync(join(dir, '.template', 'owned.txt'), 'extra.txt\n');
  writeFileSync(join(dir, 'extra.txt'), 'extra\n');
  // A line of the project block is no local edit.
  const agents = join(dir, 'AGENTS.md');
  writeFileSync(agents, readFileSync(agents, 'utf8').replace('<!-- project:start -->\n', '<!-- project:start -->\nOwn line.\n'));
  const answers = readFileSync(join(dir, '.afe-answers.json'), 'utf8');
  const seen = [];
  const options = { useDefaults: true, interactive: false, quiet: true };
  const refused = await project.update(dir, { ...options, confirm: async (preview) => (seen.push(preview), false) });
  assert.deepEqual(seen, [{ edited: ['.template/owned.txt', '.claude/rules/docs.md'], removed: ['extra.txt'] }]);
  assert.equal(refused.cancelled, true);
  assert.match(readFileSync(docs, 'utf8'), /A local edit\.\n$/);
  assert.ok(existsSync(join(dir, 'extra.txt')));
  assert.equal(readFileSync(join(dir, '.afe-answers.json'), 'utf8'), answers);

  const done = await project.update(dir, { ...options, confirm: async () => true });
  assert.deepEqual([done.edited, done.removed], [['.template/owned.txt', '.claude/rules/docs.md'], ['extra.txt']]);
  assert.doesNotMatch(readFileSync(docs, 'utf8'), /A local edit/);
  assert.ok(!existsSync(join(dir, 'extra.txt')));
  assert.match(readFileSync(agents, 'utf8'), /Own line\./);
});

test('create with --force writes nothing through a symbolic link in the directory', async () => {
  const outer = mkdtempSync(join(tmpdir(), 'afe-'));
  mkdirSync(join(outer, 'p'));
  mkdirSync(join(outer, 'outside'));
  symlinkSync(join(outer, 'outside'), join(outer, 'p', '.claude'));
  await assert.rejects(
    project.create(join(outer, 'p'), { given: base, useDefaults: true, interactive: false, quiet: true, git: false, force: true }),
    /goes through the symbolic link \.claude; nothing was changed/,
  );
  assert.deepEqual(readdirSync(join(outer, 'outside')), []);
  assert.deepEqual(readdirSync(join(outer, 'p')), ['.claude']);
});
