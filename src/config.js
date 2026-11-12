// The template's questions, file classes, tasks, and migrations: what copier.yml held before the
// template moved to npm. Maintainers: docs/maintaining.md.

export const ANSWERS_FILE = '.afe-answers.json';
export const LEGACY_ANSWERS_FILE = '.copier-answers.yml';
export const TEMPLATE_URL = 'https://github.com/dev-oleksandrv/create-afe-project';

// Template files whose name differs from the generated one, because npm never publishes the
// generated name.
export const RENAMES = { _gitignore: '.gitignore' };

// Seeded files: created once, owned by the project afterwards (docs/documentation-rules.md,
// section 9, in a generated project). An update creates a missing one; it changes an existing one
// only through an entry of MIGRATIONS, such as 2.0.1, which can replace a default one.
export const SEEDED = [
  'README.md',
  'CLAUDE.md',
  '.gitignore',
  'docs/README.md',
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

// Migrations of an update, by the version that introduces them. `before` runs before the template
// files are written, `after` after them; both run in the project directory, as bash commands,
// with AFE_TEMPLATE set to the template directory of this package and AFE_NOTES to a file whose
// lines the update reports as things to do by hand.
// A migration runs when its version is above the project's recorded version and at most the
// package's.
export const MIGRATIONS = [
  // 0.5.0 replaces the seeded .claude/protected-paths, which the update deletes, with
  // .claude/path-classes: its glob lines are kept as class approval, and the file is removed.
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
  // not template-owned and still name the .harness/ paths, such as the seeded map docs/README.md, are
  // reported for a change by hand.
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
];

// Warnings about the answers of a Copier answers file that have no question here and are dropped:
// a docs_language other than English, since documents are English only (AGENTS.md, section 5).
// ecosystems gets none: the seeded .claude/path-classes gates the ecosystems without a question.
export function legacyNotes(answers) {
  const notes = [];
  const language = answers.docs_language;
  if (language != null && String(language).trim() !== '' && !/^\s*(english|en)\s*$/i.test(String(language))) {
    notes.push(`docs_language was ${language}; it is not carried over: documents stay in English (AGENTS.md, section 5)`);
  }
  return notes;
}
