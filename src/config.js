// The template's questions, file classes, tasks, and migrations: what copier.yml held before the
// template moved to npm. Maintainers: docs/maintaining.md.

export const ANSWERS_FILE = '.afe-answers.json';
export const LEGACY_ANSWERS_FILE = '.copier-answers.yml';
export const TEMPLATE_URL = 'https://github.com/dev-oleksandrv/create-afe-project';

// Template files whose name differs from the generated one, because npm never publishes the
// generated name.
export const RENAMES = { _gitignore: '.gitignore' };

// Seeded files: created once, owned by the project afterwards (docs/documentation-rules.md,
// section 9, in a generated project). An update creates a missing one and never changes one.
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
    help: 'Project name, as written in prose (for example "acme")',
    validate: (v) => (v.trim() ? undefined : 'Required'),
  },
  {
    name: 'project_description',
    type: 'str',
    help: 'One sentence that says what the project is, ending with a period',
    validate: (v) => (v.trim().endsWith('.') ? undefined : 'End the sentence with a period'),
  },
  {
    name: 'github_repo',
    type: 'str',
    help: 'GitHub repository as owner/name',
    validate: (v) => (/^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(v) ? undefined : 'Use the form owner/name'),
  },
  {
    name: 'ci_runner',
    type: 'choice',
    help: 'Where CI jobs run by default; the repository variable CI_RUNS_ON overrides it',
    choices: [
      { label: 'GitHub-hosted runner (ubuntu-latest)', value: 'github-hosted' },
      { label: 'Self-hosted Linux runner', value: 'self-hosted' },
    ],
    default: 'github-hosted',
  },
  {
    name: 'self_hosted_labels',
    type: 'str',
    help: 'Labels of the self-hosted Linux runner, as a JSON array',
    default: '["self-hosted"]',
    when: (a) => a.ci_runner === 'self-hosted',
    validate: (v) =>
      LABELS.test(v) ? undefined : 'Enter a JSON array of quoted labels, such as ["self-hosted", "linux"]',
  },
  {
    name: 'docs_review',
    type: 'bool',
    help: 'Review every pull request with Claude (needs the Claude GitHub App and the CLAUDE_CODE_OAUTH_TOKEN secret)',
    default: true,
  },
  {
    name: 'code_review',
    type: 'bool',
    help: 'Review pull requests that change code against the review rubric with Claude (needs the Claude GitHub App and the CLAUDE_CODE_OAUTH_TOKEN secret)',
    default: true,
  },
  {
    name: 'dual_review',
    type: 'bool',
    help: 'Review a branch before its pull request opens by the class of its paths, with the Codex CLI or a Claude subagent, and both in a Santa loop for class high (the loop needs the Codex CLI where Claude Code runs)',
    default: false,
  },
  {
    name: 'secret_scan',
    type: 'bool',
    help: 'Scan every pull request and push to main for secrets with gitleaks in CI (downloaded at a pinned version; nothing to install)',
    default: true,
  },
  {
    name: 'acceptance_check',
    type: 'bool',
    help: "Check that every identifier of a pull request's Acceptance section appears in a test file (set TEST_GLOBS in .claude/harness.conf)",
    default: false,
  },
  {
    name: 'fail_without_change',
    type: 'bool',
    help: "Check that each new or changed test fails on the base, with the project's own test command (set FWC_TEST in .claude/harness.conf)",
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

export function messageAfterCreate(a) {
  const steps = ['protect main with scripts/protect-branch.sh', 'set up the CI runner'];
  if (a.docs_review || a.code_review) steps.push('the CLAUDE_CODE_OAUTH_TOKEN secret, and the Claude GitHub App');
  if (a.dual_review) steps.push('install and sign in to the Codex CLI');
  steps.push('turn on secret scanning and push protection (Settings, Code security)');
  return (
    `${a.project_name} is ready. Next: make the initial commit on main (the one direct commit that ` +
    'docs/contributing.md allows), add the remote origin, push, run git remote set-head origin -a, ' +
    `${steps.join(', ')}, then run scripts/check.sh.`
  );
}

// Migrations of an update, by the version that introduces them. `before` runs before the template
// files are written, `after` after them; both run in the project directory, as bash commands.
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
];
