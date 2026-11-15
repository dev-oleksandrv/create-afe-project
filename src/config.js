// The template's questions, file classes, tasks, and migrations. Maintainers: docs/maintaining.md.

export const ANSWERS_FILE = '.afe-answers.json';
export const TEMPLATE_URL = 'https://github.com/dev-oleksandrv/create-afe-project';

// Template files whose name differs from the generated one, because npm never publishes the
// generated name.
export const RENAMES = { _gitignore: '.gitignore' };

// Seeded files: created once, owned by the project afterwards. An update creates a missing one; it
// changes an existing one only through an entry of MIGRATIONS, such as 3.0.0, which can replace a
// default one.
export const SEEDED = [
  'README.md',
  'CLAUDE.md',
  '.gitignore',
  '.claude/risky-paths',
  '.claude/harness.conf',
  '.claude/settings.project.json',
];

// Generated files: the Claude Code settings and the ownership manifest are rebuilt after every
// create and update, in this order.
export const TASKS = ['scripts/gen-settings.sh', 'scripts/check-template.sh --write'];

// The files that TASKS write, each through a plain write that follows a symbolic link: create and
// update check them as they check the files they write themselves, before they change anything.
export const GENERATED = ['.claude/settings.json', '.template/owned.sha256'];

// Questions that 3.0.0 and 5.0.0 removed: a recorded answer to one is dropped, and a --data or
// --data-file value for one, such as from an older answers file, is ignored.
export const REMOVED_QUESTIONS = ['docs_review', 'dual_review', 'acceptance_check', 'fail_without_change'];

const LABELS = /^\[\s*"[A-Za-z0-9_.:-]+"(\s*,\s*"[A-Za-z0-9_.:-]+")*\s*\]$/;

// The wizard, in order. `when` decides whether a question is asked; an unasked question takes no
// answer. `validate` returns an error message or nothing.
export const QUESTIONS = [
  {
    name: 'project_name',
    type: 'str',
    help: 'Project name (for example: acme)',
    validate: (v) => (v.trim() ? undefined : 'Required'),
  },
  {
    name: 'project_description',
    type: 'str',
    help: 'What is the project? One sentence, ending with a period',
    validate: (v) => (v.trim().endsWith('.') ? undefined : 'End the sentence with a period'),
  },
  {
    name: 'github_repo',
    type: 'str',
    help: 'GitHub repository (owner/name)',
    validate: (v) => (/^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(v) ? undefined : 'Use the form owner/name'),
  },
  {
    name: 'ci_runner',
    type: 'choice',
    help: 'Where should CI run? (the repository variable CI_RUNS_ON can change it later)',
    choices: [
      { label: "On GitHub's servers (ubuntu-latest)", value: 'github-hosted' },
      { label: 'On your own Linux machine (self-hosted runner)', value: 'self-hosted' },
    ],
    default: 'github-hosted',
  },
  {
    name: 'self_hosted_labels',
    type: 'str',
    help: 'Labels of your runner, as a JSON array (for example: ["self-hosted", "linux"])',
    default: '["self-hosted"]',
    when: (a) => a.ci_runner === 'self-hosted',
    validate: (v) =>
      LABELS.test(v) ? undefined : 'Enter a JSON array of quoted labels, such as ["self-hosted", "linux"]',
  },
  {
    name: 'code_review',
    type: 'bool',
    help: 'Let Claude also review pull requests that change code in CI? (needs the Claude GitHub App and the CLAUDE_CODE_OAUTH_TOKEN secret)',
    default: false,
  },
  {
    name: 'secret_scan',
    type: 'bool',
    help: 'Scan pull requests and pushes to main for leaked secrets? (gitleaks in CI; nothing to install)',
    default: true,
  },
];

// Values the templates use that are derived from the answers, never asked.
export function computed(answers) {
  return {
    ci_runs_on_default:
      answers.ci_runner === 'self-hosted' ? answers.self_hosted_labels : '["ubuntu-latest"]',
    template_url: TEMPLATE_URL,
  };
}

export function messageAfterCreate(a, commit = { done: false }) {
  const steps = [];
  steps.push(
    commit.done
      ? 'the generated files are committed on main'
      : `commit the generated files on main (the one direct commit to main; not made here: ${commit.reason ?? 'not asked'})`,
  );
  steps.push('add the remote origin, push, and run git remote set-head origin -a');
  steps.push('protect main and apply the repository settings with scripts/protect-branch.sh (merge commits only, head branches deleted, secret scanning where the plan offers it)');
  steps.push('set up the CI runner');
  if (a.code_review) steps.push('add the CLAUDE_CODE_OAUTH_TOKEN secret and install the Claude GitHub App');
  steps.push('run scripts/check.sh');
  steps.push('run /afe-init in Claude Code to set up the code, its checks, and how to run the product');
  return `${a.project_name} is ready. Next:\n${steps.map((s, i) => `  ${i + 1}. ${s}`).join('\n')}`;
}

// The default .claude/harness.conf of every 2.x release, by Git blob hash: 2.0.0 and 2.1.0 seed
// the same file, which has no template expressions.
const HARNESS_CONF_2_X = ['8392606ca3dd50295ef24be237f7d69cdfb6bef8'];

// Names of documents and files that 3.0.0 removed, as plain substrings: a project file that still
// names one gets a warning after the update.
const REMOVED_IN_3_0_0 = [
  'docs/documentation-rules.md', 'docs/contributing.md', 'docs/testing-rules.md', 'docs/README.md',
  'protect-docs.sh', 'stop-check-', 'stop-run-project-hooks.sh', 'pr-metrics.sh', 'docs-review',
  'dual-review', '.github/workflows/docs.yml',
];

// Names that 5.0.0 removed, as plain substrings.
const REMOVED_IN_5_0_0 = [
  'create-pr', 'skills/review/', 'check-decisions.sh', 'gen-decisions-index.sh', 'check-review-evidence',
  'path-classes', 'stop-dispatch.sh', 'check-acceptance.sh', 'fail-without-change', 'check.sh --if-changed',
  'lib/classes.sh', 'lib/stamp.sh',
];

// The bash lines that warn about each tracked file that is not a symbolic link, not
// template-owned, not generated, not .claude/path-classes (which 5.0.0 removes), and not warned
// about already, and that names one of the removed names; nothing is changed.
const warnRemoved = (names) => [
  `{ git -c core.quotepath=off ls-files 2> /dev/null || true; } | { if [ -f .template/owned.txt ]; then grep -v -x -F -f .template/owned.txt || true; else cat; fi; } |`,
  `  while IFS= read -r p; do`,
  `    case $p in .afe-answers.json|.claude/settings.json|.claude/path-classes|.template/*|docs/decisions/README.md|CHANGELOG.md|node_modules/*|*/node_modules/*) continue ;; esac`,
  `    [ -f "$p" ] && [ ! -L "$p" ] || continue`,
  `    if [ -f "$AFE_NOTES" ] && grep -q -x -F -e "$p" <(cut -d ' ' -f 1 "$AFE_NOTES"); then continue; fi`,
  `    hit=$({ grep -o -I -F ${names.map((n) => `-e '${n}'`).join(' ')} -- "$p" 2> /dev/null || true; } | awk '!s[$0]++' | paste -s -d , - | sed 's/,/, /g')`,
  `    if [ -n "$hit" ]; then echo "$p names removed files ($hit); update or remove those references" >> "$AFE_NOTES"; fi`,
  `  done`,
];

// Migrations of an update, by the version that introduces them. `before` runs before the template
// files are written, `after` after them; both run in the project directory, as bash commands,
// with AFE_TEMPLATE set to the template directory of this package, AFE_NOTES to a file whose
// lines the update reports as things to do by hand, and AFE_TMP to an empty directory of the
// update's own for temporary files. A migration writes through no symbolic link: a seeded file
// that is one is left as it is, with a note, and a temporary file goes to AFE_TMP, never next to
// its target.
// A migration runs when its version is above the project's recorded version and at most the
// package's. It runs with `set -euo pipefail`, so a failing command fails it, and the update with
// it; a part that may fail says so with `|| true`. The update records the new version only after
// every migration succeeded, so a migration runs again on the next update after a failure: each
// one leaves the project as it is when it runs a second time, apart from its notes.
export const MIGRATIONS = [
  // 3.0.0 has a fix-loop cap of 2. A .claude/harness.conf that is still a 2.x default is replaced
  // with the current default; one the project changed keeps its values (5.0.0 reports the keys
  // that nothing reads any more), and one that is a symbolic link stays as it is. The path
  // classes of 3.0.0 are gone: 5.0.0 below turns .claude/path-classes into .claude/risky-paths.
  // The template stops seeding the documentation map docs/README.md: an existing one stays, as a
  // project file, and the update says so. The files the template no longer owns go the usual
  // way: they are not in the new .template/owned.txt. Last, each tracked file that names a
  // removed file gets a warning (warnRemoved). Best effort: a hash that Git cannot compute (the
  // file then counts as changed by the project), the list of tracked files outside a Git
  // repository (none), and a file that grep cannot read (not scanned).
  {
    version: '3.0.0',
    after: [
      `set -euo pipefail`,
      `f=.claude/harness.conf`,
      `if [ -L $f ]; then`,
      `  echo "$f is a symbolic link, so the update does not migrate it: by hand, replace a 2.x default with the template's default" >> "$AFE_NOTES"`,
      `elif [ -f $f ]; then`,
      `  case "$(git hash-object --no-filters $f 2> /dev/null || true)" in`,
      `    ${HARNESS_CONF_2_X.join('|')}) cat "$AFE_TEMPLATE/$f" > $f ;;`,
      `    *) ;;`,
      `  esac`,
      `fi`,
      `if [ -f docs/README.md ]; then`,
      `  echo "docs/README.md is no longer maintained by the template: it stays as a project file, and scripts/check.sh fails on its links and paths to files that do not exist, such as the removed docs/documentation-rules.md; update it, or delete it together with the links to it, such as those in README.md" >> "$AFE_NOTES"`,
      `fi`,
      ...warnRemoved(REMOVED_IN_3_0_0),
    ].join('\n'),
  },
  // 4.0.0 leaves two steps to the project (CHANGELOG.md, 4.0.0), and the update reports each one
  // that applies; it changes nothing. A Stop hook of the project, .claude/hooks/project/stop/*.sh,
  // that .claude/settings.project.json does not name: the Stop dispatcher no longer runs it, so it
  // goes under hooks.Stop there. FWC_INSTALL and FWC_CLASSIFIER in .claude/harness.conf: nothing
  // reads them, since the fail-without-change driver installs with SETUP.
  {
    version: '4.0.0',
    after: [
      `set -euo pipefail`,
      `f=.claude/harness.conf`,
      `keys=`,
      `for k in FWC_INSTALL FWC_CLASSIFIER; do`,
      `  if [ -f $f ] && grep -q -E "^[[:space:]]*$k=" $f; then keys=\${keys:+$keys, }$k; fi`,
      `done`,
      `if [ -n "$keys" ]; then`,
      `  echo "$f sets $keys, which 4.0.0 no longer reads: delete them; the fail-without-change driver installs with SETUP" >> "$AFE_NOTES"`,
      `fi`,
      `for h in .claude/hooks/project/stop/*.sh; do`,
      `  [ -f "$h" ] || continue`,
      `  if [ -f .claude/settings.project.json ] && grep -q -F -e "$h" .claude/settings.project.json; then continue; fi`,
      `  echo "$h no longer runs: since 4.0.0 the Stop dispatcher does not run .claude/hooks/project/stop/, so register it under hooks.Stop in .claude/settings.project.json" >> "$AFE_NOTES"`,
      `done`,
    ].join('\n'),
  },
  // 5.0.0 leaves the process to the developer's own setup: the template keeps the checks, the
  // limits, and the facts of the project. The update removes the template-owned files of the
  // removed parts by itself. This migration: copies the high globs of .claude/path-classes that
  // .claude/risky-paths (created just before, as a missing seeded file) does not have, and
  // removes .claude/path-classes; removes a generated decision index docs/decisions/README.md;
  // and reports what is left to do by hand: the keys of .claude/harness.conf that nothing
  // reads, the ruleset that still requires the check `integrity`, and each project file that
  // names a removed file. A symbolic link is never changed or removed.
  {
    version: '5.0.0',
    after: [
      `set -euo pipefail`,
      `old=.claude/path-classes new=.claude/risky-paths`,
      `if [ -L $old ] || [ -L $new ]; then`,
      `  echo "$old or $new is a symbolic link, so the update does not migrate it: by hand, put the high globs of $old into $new, one per line, and delete $old" >> "$AFE_NOTES"`,
      `elif [ -f $old ]; then`,
      `  if [ -f $new ]; then`,
      `    awk '$1 == "high" && $2 != "" {print $2}' $old | while IFS= read -r g; do`,
      `      if ! grep -q -x -F -e "$g" $new; then printf '%s\\n' "$g" >> $new; fi`,
      `    done`,
      `  fi`,
      `  rm -f $old`,
      `  echo "$old is replaced by $new, which holds its high globs: the classes gate and normal are gone, and nothing lists gate files any more" >> "$AFE_NOTES"`,
      `fi`,
      `f=docs/decisions/README.md`,
      `if [ -f $f ] && [ ! -L $f ] && grep -q -F 'gen-decisions-index.sh' $f; then`,
      `  rm -f $f`,
      `  echo "$f, the generated decision index, is removed: nothing generates it any more; remove the links to it" >> "$AFE_NOTES"`,
      `fi`,
      `f=.claude/harness.conf`,
      `keys=`,
      `for k in RALPH_MAX_ITERATIONS REVIEW_MAX_ROUNDS DIFF_WARN_LINES ID_PATTERN TEST_GLOBS FWC_TOOLCHAIN_GLOBS FWC_TEST; do`,
      `  if [ -f $f ] && grep -q -E "^[[:space:]]*$k=" $f; then keys=\${keys:+$keys, }$k; fi`,
      `done`,
      `if [ -n "$keys" ]; then`,
      `  echo "$f sets $keys, which 5.0.0 no longer reads: delete them with their comments" >> "$AFE_NOTES"`,
      `fi`,
      `echo "scripts/protect-branch.sh: the ruleset of 4.x requires the check integrity, which no workflow reports any more; the owner runs scripts/protect-branch.sh once more, before this update is merged, or every pull request waits for that check" >> "$AFE_NOTES"`,
      `echo "decision records: status and decision-makers in their front matter are no longer read; a record is accepted when written, and existing records stay as they are" >> "$AFE_NOTES"`,
      ...warnRemoved(REMOVED_IN_5_0_0),
    ].join('\n'),
  },
];
