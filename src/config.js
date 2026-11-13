// The template's questions, file classes, tasks, and migrations: what copier.yml held before the
// template moved to npm. Maintainers: docs/maintaining.md.

export const ANSWERS_FILE = '.afe-answers.json';
export const LEGACY_ANSWERS_FILE = '.copier-answers.yml';
export const TEMPLATE_URL = 'https://github.com/dev-oleksandrv/create-afe-project';

// Template files whose name differs from the generated one, because npm never publishes the
// generated name.
export const RENAMES = { _gitignore: '.gitignore' };

// Seeded files: created once, owned by the project afterwards. An update creates a missing one; it
// changes an existing one only through an entry of MIGRATIONS, such as 2.0.1 or 3.0.0, which can
// replace a default one.
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

// The seeded .claude/harness.conf and .claude/path-classes as 2.0.0 created them, by Git blob hash
// (git hash-object): a project that converted from Copier with 2.0.0 got these defaults next to
// its own .harness/ files.
const SEEDED_2_0_0 = {
  'harness.conf': '8392606ca3dd50295ef24be237f7d69cdfb6bef8',
  'path-classes': '8cf0e645771ce2d60146eccfa09a0987fbddc99e',
};

// The default .claude/path-classes of every 2.x release, by Git blob hash: 2.0.0 and 2.1.0.
const PATH_CLASSES_2_X = [SEEDED_2_0_0['path-classes'], 'b049d71a405812909923fe56a12336f307f41a9c'];

// The default .claude/harness.conf of every 2.x release, by Git blob hash: 2.0.0 and 2.1.0 seed
// the same file, which has no template expressions.
const HARNESS_CONF_2_X = [SEEDED_2_0_0['harness.conf']];

// Names of documents and files that 3.0.0 removed, as plain substrings: a project file that still
// names one gets a warning after the update.
const REMOVED_IN_3_0_0 = [
  'docs/documentation-rules.md', 'docs/contributing.md', 'docs/testing-rules.md', 'docs/README.md',
  'protect-docs.sh', 'stop-check-', 'stop-run-project-hooks.sh', 'pr-metrics.sh', 'docs-review',
  'dual-review', '.github/workflows/docs.yml',
];

// Migrations of an update, by the version that introduces them. `before` runs before the template
// files are written, `after` after them; both run in the project directory, as bash commands,
// with AFE_TEMPLATE set to the template directory of this package and AFE_NOTES to a file whose
// lines the update reports as things to do by hand.
// A migration runs when its version is above the project's recorded version and at most the
// package's.
export const MIGRATIONS = [
  // 0.5.0 replaces the seeded .claude/protected-paths, which the update deletes, with
  // .claude/path-classes: its glob lines are kept as class approval lines (which 3.0.0 ignores),
  // and the file is removed.
  {
    version: '0.5.0',
    before: '[ ! -f .claude/protected-paths ] || cp .claude/protected-paths .claude/protected-paths.pre-0.5',
    after:
      "[ ! -f .claude/protected-paths.pre-0.5 ] || { grep -v -E '^[[:space:]]*(#|$)' .claude/protected-paths.pre-0.5 | sed 's/^/approval /' >> .claude/path-classes; rm -f .claude/protected-paths.pre-0.5 .claude/protected-paths; }",
  },
  // 2.0.1 moves .harness/harness.conf and .harness/path-classes, where the Copier template keeps
  // them since its 0.7.0, back to .claude/, with the reverse of that release's rename in their
  // lines; 2.0.0 ignored them and seeded the defaults. A .claude/ file is replaced only when it is
  // a default (of 2.0.0 or of this package); otherwise both stay, and the update reports the merge
  // by hand. .harness/ is removed when nothing else is left in it. After a move, the files that are
  // not template-owned and still name the .harness/ paths, such as the seeded map docs/README.md of
  // 2.x, are reported for a change by hand.
  {
    version: '2.0.1',
    after: [
      `[ -f "$AFE_NOTES.moved" ] || exit 0`,
      `grep -rlE '[.]harness/(harness[.]conf|path-classes)' --exclude-dir=.git --exclude-dir=.harness --exclude-dir=node_modules . 2> /dev/null |`,
      `  sed 's#^[.]/##' | { [ -f .template/owned.txt ] && grep -v -x -F -f .template/owned.txt || cat; } |`,
      `  sed 's#.*#replace .harness/ with .claude/ in & by hand: it names a .harness/ file that moved to .claude/#' >> "$AFE_NOTES"`,
      `exit 0`,
    ].join('\n'),
    before: [
      `for f in harness.conf path-classes; do`,
      `  [ -f .harness/$f ] || continue`,
      `  case $f in harness.conf) old=${SEEDED_2_0_0['harness.conf']} ;; *) old=${SEEDED_2_0_0['path-classes']} ;; esac`,
      `  if [ -f .claude/$f ] && [ "$(git hash-object --no-filters .claude/$f 2> /dev/null)" != "$old" ] && ! cmp -s .claude/$f "$AFE_TEMPLATE/.claude/$f"; then`,
      `    echo "merge .harness/$f into .claude/$f by hand, then delete .harness/$f: both exist, and .claude/$f is not the template's default" >> "$AFE_NOTES"`,
      `    continue`,
      `  fi`,
      `  mkdir -p .claude && sed 's#[.]harness/harness[.]conf#.claude/harness.conf#g; s#[.]harness/path-classes#.claude/path-classes#g' .harness/$f > .claude/$f.tmp &&`,
      `    mv .claude/$f.tmp .claude/$f && rm .harness/$f && : > "$AFE_NOTES.moved" || exit 1`,
      `done`,
      `[ ! -d .harness ] || rmdir .harness 2> /dev/null || true`,
    ].join('\n'),
  },
  // 3.0.0 has two configurable path classes, high and gate, and a fix-loop cap of 2. A seeded
  // .claude/path-classes that is still a 2.x default is replaced with the 3.0.0 default; one the
  // project changed stays, and the update reports its approval lines (now ignored) and the
  // ecosystem gate blocks of 2.1.0 (now added by afe-init for the chosen stack) for a change by
  // hand. A .claude/harness.conf that is still a 2.x default is replaced with the 3.0.0 default;
  // in one the project changed, RALPH_MAX_ITERATIONS and REVIEW_MAX_ROUNDS go to 2 only where they
  // still hold the 2.x defaults, 5 and 3. The template stops seeding the documentation map
  // docs/README.md: an existing one stays, as a project file, and the update says so. The files
  // the template no longer owns, such as the removed rule documents, Stop hooks, and skills, go
  // the usual way: they are not in the new .template/owned.txt. Last, each tracked file that is
  // not template-owned, not generated, and not warned about above, and that names a removed file,
  // gets a warning; nothing is changed.
  {
    version: '3.0.0',
    after: [
      `f=.claude/path-classes`,
      `if [ -f $f ] && ! cmp -s $f "$AFE_TEMPLATE/$f"; then`,
      `  case "$(git hash-object --no-filters $f 2> /dev/null)" in`,
      `    ${PATH_CLASSES_2_X.join('|')}) cat "$AFE_TEMPLATE/$f" > $f ;;`,
      `    *) echo "$f is not a default of the template, so it stays as it is: remove its approval lines by hand (3.0.0 ignores class approval and has only high and gate), and you may trim the ecosystem gate blocks to the files of your stack" >> "$AFE_NOTES" ;;`,
      `  esac`,
      `fi`,
      `f=.claude/harness.conf`,
      `if [ -f $f ]; then`,
      `  case "$(git hash-object --no-filters $f 2> /dev/null)" in`,
      `    ${HARNESS_CONF_2_X.join('|')}) cat "$AFE_TEMPLATE/$f" > $f ;;`,
      `    *) if grep -q -E '^(RALPH_MAX_ITERATIONS=5|REVIEW_MAX_ROUNDS=3)[[:space:]]*$' $f; then`,
      `      sed -E 's/^RALPH_MAX_ITERATIONS=5[[:space:]]*$/RALPH_MAX_ITERATIONS=2/; s/^REVIEW_MAX_ROUNDS=3[[:space:]]*$/REVIEW_MAX_ROUNDS=2/' $f > $f.tmp &&`,
      `        cat $f.tmp > $f && rm $f.tmp || exit 1`,
      `    fi ;;`,
      `  esac`,
      `fi`,
      `[ ! -f docs/README.md ] ||`,
      `  echo "docs/README.md is no longer maintained by the template: it stays as a project file, and scripts/check.sh fails on its links and paths to files that do not exist, such as the removed docs/documentation-rules.md; update it, or delete it together with the links to it, such as those in README.md" >> "$AFE_NOTES"`,
      `git -c core.quotepath=off ls-files 2> /dev/null | { [ -f .template/owned.txt ] && grep -v -x -F -f .template/owned.txt || cat; } |`,
      `  while IFS= read -r p; do`,
      `    case $p in .claude/settings.json|.template/*|docs/decisions/README.md|node_modules/*|*/node_modules/*) continue ;; esac`,
      `    [ -f "$p" ] && ! { cut -d ' ' -f 1 "$AFE_NOTES" 2> /dev/null | grep -q -x -F -e "$p"; } || continue`,
      `    hit=$(grep -o -I -F ${REMOVED_IN_3_0_0.map((n) => `-e '${n}'`).join(' ')} -- "$p" 2> /dev/null | awk '!s[$0]++' | paste -s -d , - | sed 's/,/, /g')`,
      `    [ -z "$hit" ] || echo "$p names removed files ($hit); update or remove those references" >> "$AFE_NOTES"`,
      `  done`,
      `exit 0`,
    ].join('\n'),
  },
];

// Warnings about the answers of a Copier answers file that have no question here and are dropped:
// a docs_language other than English, since documents are English only (.claude/rules/docs.md).
// ecosystems gets none: the seeded .claude/path-classes gates the ecosystems without a question.
export function legacyNotes(answers) {
  const notes = [];
  const language = answers.docs_language;
  if (language != null && String(language).trim() !== '' && !/^\s*(english|en)\s*$/i.test(String(language))) {
    notes.push(`docs_language was ${language}; it is not carried over: documents stay in English (.claude/rules/docs.md)`);
  }
  return notes;
}
