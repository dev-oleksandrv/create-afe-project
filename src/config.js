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
  '.claude/path-classes',
  '.claude/harness.conf',
  '.claude/settings.project.json',
];

// Generated files: the Claude Code settings, the ownership manifest, and the decision index are
// rebuilt after every create and update, in this order.
export const TASKS = [
  'scripts/gen-settings.sh',
  'scripts/check-template.sh --write',
  'scripts/gen-decisions-index.sh > docs/decisions/README.md',
];

// The files that TASKS write, each through a plain write that follows a symbolic link: create and
// update check them as they check the files they write themselves, before they change anything.
export const GENERATED = ['.claude/settings.json', '.template/owned.sha256', 'docs/decisions/README.md'];

// Questions of earlier versions that 3.0.0 removed: a recorded answer to one is dropped, and a
// --data or --data-file value for one, such as from a 2.x answers file, is ignored.
export const REMOVED_QUESTIONS = ['docs_review', 'dual_review'];

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
  {
    name: 'acceptance_check',
    type: 'bool',
    help: 'Require a test for every requirement ID a pull request lists under Acceptance? (you set TEST_GLOBS in .claude/harness.conf later)',
    default: true,
  },
  {
    name: 'fail_without_change',
    type: 'bool',
    help: 'Require every new or changed test to fail without the change? (you set FWC_TEST in .claude/harness.conf later)',
    default: false,
  },
  {
    name: 'licence_check',
    type: 'bool',
    help: 'Check the licence of each new dependency in reviews and in /afe-init? (the project documents which licences it allows)',
    default: false,
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
  steps.push('optionally install and sign in to the Codex CLI: the review before a pull request uses it when it is installed');
  steps.push('run scripts/check.sh');
  steps.push('run /afe-init in Claude Code to set up the code and its checks');
  return `${a.project_name} is ready. Next:\n${steps.map((s, i) => `  ${i + 1}. ${s}`).join('\n')}`;
}

// The default .claude/path-classes of every 2.x release, by Git blob hash (git hash-object): 2.0.0
// and 2.1.0.
const PATH_CLASSES_2_X = ['8cf0e645771ce2d60146eccfa09a0987fbddc99e', 'b049d71a405812909923fe56a12336f307f41a9c'];

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
  // 3.0.0 has two configurable path classes, high and gate, and a fix-loop cap of 2. A seeded
  // .claude/path-classes that is still a 2.x default is replaced with the 3.0.0 default; one the
  // project changed stays, and the update reports its approval lines (now ignored) and the
  // ecosystem gate blocks of 2.1.0 (now added by afe-init for the chosen stack) for a change by
  // hand. A .claude/harness.conf that is still a 2.x default is replaced with the 3.0.0 default;
  // in one the project changed, RALPH_MAX_ITERATIONS and REVIEW_MAX_ROUNDS go to 2 only where they
  // still hold the 2.x defaults, 5 and 3. Either file as a symbolic link stays as it is, and the
  // update reports the change by hand. The template stops seeding the documentation map
  // docs/README.md: an existing one stays, as a project file, and the update says so. The files
  // the template no longer owns, such as the removed rule documents, Stop hooks, and skills, go
  // the usual way: they are not in the new .template/owned.txt. Last, each tracked file that is
  // not a symbolic link, not template-owned, not generated (as the answers file, which the update
  // writes after the migrations), and not warned about above, and that names a removed file, gets
  // a warning; nothing is changed. Best effort: a hash that Git cannot compute (the file then
  // counts as changed by the project), the list of tracked files outside a Git repository (none),
  // and a file that grep cannot read (not scanned).
  {
    version: '3.0.0',
    after: [
      `set -euo pipefail`,
      `f=.claude/path-classes`,
      `if [ -L $f ]; then`,
      `  echo "$f is a symbolic link, so the update does not migrate it: by hand, replace a 2.x default with the template's default, or remove its approval lines (3.0.0 ignores class approval and has only high and gate)" >> "$AFE_NOTES"`,
      `elif [ -f $f ] && ! cmp -s $f "$AFE_TEMPLATE/$f"; then`,
      `  case "$(git hash-object --no-filters $f 2> /dev/null || true)" in`,
      `    ${PATH_CLASSES_2_X.join('|')}) cat "$AFE_TEMPLATE/$f" > $f ;;`,
      `    *) echo "$f is not a default of the template, so it stays as it is: remove its approval lines by hand (3.0.0 ignores class approval and has only high and gate), and you may trim the ecosystem gate blocks to the files of your stack" >> "$AFE_NOTES" ;;`,
      `  esac`,
      `fi`,
      `f=.claude/harness.conf`,
      `if [ -L $f ]; then`,
      `  echo "$f is a symbolic link, so the update does not migrate it: by hand, replace a 2.x default with the template's default, or set RALPH_MAX_ITERATIONS and REVIEW_MAX_ROUNDS to 2 where they still hold 5 and 3" >> "$AFE_NOTES"`,
      `elif [ -f $f ]; then`,
      `  case "$(git hash-object --no-filters $f 2> /dev/null || true)" in`,
      `    ${HARNESS_CONF_2_X.join('|')}) cat "$AFE_TEMPLATE/$f" > $f ;;`,
      `    *) if grep -q -E '^(RALPH_MAX_ITERATIONS=5|REVIEW_MAX_ROUNDS=3)[[:space:]]*$' $f; then`,
      `      sed -E 's/^RALPH_MAX_ITERATIONS=5[[:space:]]*$/RALPH_MAX_ITERATIONS=2/; s/^REVIEW_MAX_ROUNDS=3[[:space:]]*$/REVIEW_MAX_ROUNDS=2/' $f > "$AFE_TMP/harness.conf"`,
      `      cat "$AFE_TMP/harness.conf" > $f`,
      `    fi ;;`,
      `  esac`,
      `fi`,
      `if [ -f docs/README.md ]; then`,
      `  echo "docs/README.md is no longer maintained by the template: it stays as a project file, and scripts/check.sh fails on its links and paths to files that do not exist, such as the removed docs/documentation-rules.md; update it, or delete it together with the links to it, such as those in README.md" >> "$AFE_NOTES"`,
      `fi`,
      `{ git -c core.quotepath=off ls-files 2> /dev/null || true; } | { if [ -f .template/owned.txt ]; then grep -v -x -F -f .template/owned.txt || true; else cat; fi; } |`,
      `  while IFS= read -r p; do`,
      `    case $p in .afe-answers.json|.claude/settings.json|.template/*|docs/decisions/README.md|node_modules/*|*/node_modules/*) continue ;; esac`,
      `    [ -f "$p" ] && [ ! -L "$p" ] || continue`,
      `    if [ -f "$AFE_NOTES" ] && grep -q -x -F -e "$p" <(cut -d ' ' -f 1 "$AFE_NOTES"); then continue; fi`,
      `    hit=$({ grep -o -I -F ${REMOVED_IN_3_0_0.map((n) => `-e '${n}'`).join(' ')} -- "$p" 2> /dev/null || true; } | awk '!s[$0]++' | paste -s -d , - | sed 's/,/, /g')`,
      `    if [ -n "$hit" ]; then echo "$p names removed files ($hit); update or remove those references" >> "$AFE_NOTES"; fi`,
      `  done`,
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
];
