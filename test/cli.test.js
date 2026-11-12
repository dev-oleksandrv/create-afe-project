// Unit tests of the CLI's parts; the end-to-end tests of create and update are in
// test/template/, run by scripts/checks.d/10-template.sh (docs/maintaining.md, section 3).
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { UsageError, coerce, collectAnswers, compareVersions, readAnswers } from '../src/answers.js';
import { SEEDED, legacyNotes, messageAfterCreate } from '../src/config.js';
import { TEMPLATE_DIR } from '../src/project.js';
import { renderString, renderTemplate } from '../src/render.js';

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

test('a Copier answers file is read with its version, without private keys', () => {
  const dir = mkdtempSync(join(tmpdir(), 'afe-'));
  writeFileSync(join(dir, '.copier-answers.yml'), "_commit: v0.6.0\n_src_path: x\nproject_name: s\nproject_description: 'A\n    b.'\n");
  assert.deepEqual(readAnswers(dir), { version: '0.6.0', answers: { project_name: 's', project_description: 'A b.' }, legacy: true });
  writeFileSync(join(dir, '.afe-answers.json'), JSON.stringify({ _note: 'n', _version: '0.7.0', project_name: 't' }));
  assert.deepEqual(readAnswers(dir), { version: '0.7.0', answers: { project_name: 't' }, legacy: false });
  assert.equal(readFileSync(join(dir, '.copier-answers.yml'), 'utf8').length > 0, true);
});

test('a Copier docs_language other than English gets a warning that documents stay in English', () => {
  assert.match(legacyNotes({ docs_language: 'German', ecosystems: ['node'] }).join('\n'), /^docs_language was German; .*English \(AGENTS\.md, section 5\)$/);
  for (const docs_language of ['English', 'en', '', null]) assert.deepEqual(legacyNotes({ docs_language }), []);
  assert.deepEqual(legacyNotes({ ecosystems: ['node'] }), []);
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
