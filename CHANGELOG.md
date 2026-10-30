# Changelog

All notable changes to the template are listed here, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[`docs/maintaining.md`](docs/maintaining.md), section 4.

## [Unreleased]

### Changed

- `docs/testing-rules.md`, section 4: a threat model of development gates. Gates catch honest
  mistakes and shortcuts; deliberate evasion is left to the review of the diff; product
  invariants are not development gates. The protected-paths bullet now names the forms the
  protect hook catches and what is left to the review, instead of claiming that no agent loosens
  a gate.
- `docs/documentation-rules.md`, section 7: the merge-readiness row names what
  `scripts/check-decisions.sh --ready` checks and what is left to the owner.
- `docs/contributing.md`, section 6: a finding that only deliberate evasion can exploit to bypass
  a development gate is a `nit`, a bypass of a product invariant keeps its severity, and a table
  of `should` and `nit` examples calibrates every reviewer. The Tests criterion includes the test
  plan. With `dual_review`, later rounds add the owner's decisions on the branch to the brief, and
  nothing else.
- `docs/contributing.md`, section 1: "one logical change" means one mechanism with its tests and
  owner documents, with examples.
- `docs/contributing.md`, section 3: the description gains the sections "Test plan" (always,
  written before the implementation) and "Owner decisions to confirm" (each `Decided by the
  owner` marker added on a chat instruction, confirmed by the owner with one comment); a pull
  request is ready to merge only after that confirmation. `scripts/check-decisions.sh --ready`
  does not check the confirmation.
- `docs/documentation-rules.md`, sections 3 and 7: a statement about a check names the forms it
  catches and what is left to the review; an absolute claim needs a test for each form it covers.
- `create-pr` skill: writes the two new sections and reports unconfirmed owner decisions as
  waiting on the owner. `review-code` skill: compares the code and tests with the test plan.
  `dual-review` skill: an author's self-check before the first round, the severity examples and
  the test plan in the brief, and the owner's decisions from the second round.

### Fixed

- `.claude/hooks/protect-docs.sh`: judges a target path by the git repository that holds it when
  that repository has `.template/owned.txt`, so an edit in a sibling git worktree, or in another
  generated project, asks the owner like an edit in the session's own checkout. Other paths
  inside the session's project are judged by the project as before (no git yet, a nested
  repository); paths elsewhere stay unguarded. A relative path of a shell command resolves
  against the hook input's `cwd`.

## [0.3.1] - 2026-10-30

### Changed

- `docs/contributing.md`, section 6: defines the severities `blocker`, `should`, and `nit`, and
  that a review fails on a `blocker` or `should` only; a reviewer who hesitates picks `nit`. The
  `review-code`, `docs-review`, and `dual-review` skills apply these definitions, and a `nit` no
  longer fails a round of the dual review.
- `review-code` and `docs-review` skills: in a pull request run they read changed files of
  `.claude/`, `CLAUDE.md`, and `.mcp.json` from the diff and `.claude-pr/`, because
  `anthropics/claude-code-action` restores those paths from the base branch.

## [0.3.0] - 2026-10-30

### Added

- Testing rules (`docs/testing-rules.md`), template-owned: what a test is for, how it proves
  behaviour, tests and the change they cover, and the gates no agent loosens. `AGENTS.md`,
  section 2, points to it; `docs/documentation-rules.md`, sections 2, 6, and 7, list it.
- Review of pull requests (`docs/contributing.md`, section 6): a rubric that every reviewer
  applies, the project's own criteria in an owner document that the map names under "Review
  criteria", and the rule that a defect found after the merge names what keeps the next one out.
- Module `code_review` (question `code_review`, default on): the `code-review` workflow
  (`.github/workflows/code-review.yml`) and the `review-code` skill
  (`.claude/skills/review-code/SKILL.md`) review pull requests that change code, contracts,
  checks, or workflows against that rubric with Claude Code, with the same secret and app as
  `docs-review`, and install no plugin.
- Module `dual_review` (question `dual_review`, default off): the `dual-review` skill
  (`.claude/skills/dual-review/SKILL.md`) reviews a branch before its pull request with a Claude
  subagent and the Codex CLI in a read-only sandbox, after a passing `scripts/check.sh`, for at
  most three rounds, without commits; its verdict goes under "Checks" in the description
  (`docs/contributing.md`, sections 3 and 4).

### Changed

- `create-pr` skill: waits for and answers the `code-review` run next to `docs-review`, and with
  the `dual_review` module runs the dual review when the branch has no verdict for its tree.
- `docs/contributing.md`, section 3: every review comment is answered before the merge, from
  either review workflow.
- Linter configuration (`.markdownlint-cli2.jsonc`): in `CHANGELOG.md`, headings need to be
  unique among siblings only, so that each version can have its own Added and Changed.
- Seeded `docs/README.md`: rows for the testing rules and the review of pull requests, and the
  planned "Review criteria" section. An existing project copies these rows by hand.

## [0.2.0] - 2026-10-29

### Changed

- `create-pr` skill (`.claude/skills/create-pr/SKILL.md`), with the `docs_review` module: after
  opening the pull request it waits for the `docs-review` run, answers every comment (a fix in
  its own commit, a decline with a reason, or a question for the owner), records the outcome in
  the description, and reports it; a draft or a run that does not finish is reported instead of
  waited for. `docs/contributing.md`, section 4, names the new step.

## [0.1.0] - 2026-10-29

### Added

- Agent rules (`AGENTS.md` with one project block, `CLAUDE.md`), documentation rules with file
  ownership (`docs/documentation-rules.md`), contribution and template update rules
  (`docs/contributing.md`), and the seeded documentation map (`docs/README.md`).
- Short decision records: `docs/decisions/adr-template.md` and the generated index
  `docs/decisions/README.md` (`scripts/gen-decisions-index.sh`).
- Checks behind one entry point, `scripts/check.sh`: documentation (markdownlint-cli2, lychee),
  decision records (integrity, next number, index, merge readiness), template integrity
  (`.template/owned.sha256`), and project checks from `scripts/checks.d/`.
- Claude Code hooks (protect, Stop checks, project Stop hooks from `.claude/hooks/project/stop/`)
  and skills (`create-pr`, `update-template`, and `docs-review` as the `docs_review` module).
- CI workflows `docs` (with Node.js set up), `decisions`, and `docs-review`, with the runner chosen
  by a question and overridable by the repository variable `CI_RUNS_ON`.
