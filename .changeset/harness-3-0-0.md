---
"create-afe-project": major
---

3.0.0 makes the harness cheaper and quieter, on the owner's decisions for this release: `/create-pr`
and the LLM review cost less, the documentation co-change engine is gone (it caused endless
documentation edits), the hooks work for sub-agents and in git worktrees and do nothing on an
unchanged tree, and every deterministic check of code quality stays.

- Pull requests: `/create-pr` reviews the change by default (`--skip-review` skips it) and
  watches CI by default with one blocking command (`--skip-watch` skips it). It writes the
  "Gate files" section with `scripts/check-decisions.sh --gate-section`, never by hand. After
  review fixes it runs the fast check; the full check runs once before the push. Branch, commit,
  and pull request rules live in the `create-pr` skill.
- Review: the new `review` skill replaces `dual-review` and the inline review of `create-pr`, and
  carries its rubric in `.claude/skills/review/rubric.md`, so a reviewer that is not Claude gets
  it in the brief. A high-risk path gets two reviewers over several rounds, other code one
  reviewer and one round, a Markdown-only change none.
- Modules: `docs_review` (its skill and workflow) and `dual_review` are removed. `code_review`,
  the CI review by Claude, is off by default for new projects; when its workflow exists,
  `/create-pr` waits for it and answers its findings. `acceptance_check` is on by default for new
  projects; `fail_without_change` stays optional and runs in CI only.
- Path classes: only `high` and `gate` are configurable in `.claude/path-classes`, which no longer
  names ecosystems; `afe-init` adds the gate lines of the chosen stack. Class `approval` and a
  configured class `low` are gone: an `approval` or `low` line is ignored. `--classes` prints the
  review level `none`, `one`, or `two` (was `santa`).
- Hooks: `.claude/hooks/protect-docs.sh` becomes `guard.sh`; it asks only before an edit of
  `AGENTS.md`, a known token format, and irreversible commands, and denies a push to the default
  branch. The five Stop hooks become one dispatcher, `.claude/hooks/stop-dispatch.sh`, on Stop and
  SubagentStop, which checks the worktree of the agent and skips a tree that a green stamp
  (`scripts/lib/stamp.sh`) shows unchanged since the last pass. The template integrity check runs
  in `scripts/check.sh` only. The guard hook has tests.
- Checks: `scripts/check.sh` is quiet by default (`--verbose` prints everything) and takes
  `--if-changed`; `scripts/check-docs.sh` takes a file list; the link check also fails on a
  backticked path that does not exist in `docs/` outside `docs/decisions/` and in `AGENTS.md`.
  The fix-loop caps are 2 (`RALPH_MAX_ITERATIONS`, `REVIEW_MAX_ROUNDS`). The `docs` workflow is
  now `check.yml`, with the same job name `check`.
- Documents: `docs/documentation-rules.md`, `docs/contributing.md`, `docs/testing-rules.md`, and
  the map `docs/README.md` leave the template; `AGENTS.md` is shorter, and the scoped rules
  `.claude/rules/testing.md` and `.claude/rules/docs.md` hold what survives. Document statuses,
  `verified-against`, `review-by`, owner markers, the Metrics sections, and
  `scripts/pr-metrics.sh` are removed. Accepted risk: semantic documentation drift is no longer
  reviewed by an LLM; only dead references are caught.

An update from 2.x removes the files the template no longer owns, among them the three rule
documents, the five Stop hooks, `protect-docs.sh`, `pr-metrics.sh`, the `docs-review` and
`dual-review` skills, and the `docs` and `docs-review` workflows. It drops the answers to
`docs_review` and `dual_review` and keeps the project's `code_review` and `acceptance_check`;
a 2.x answers file given as `--data-file` still works. A `.claude/path-classes` that is still a
2.x default becomes the 3.0.0 default, and so does a `.claude/harness.conf` that is still the 2.x
default. In a changed `.claude/harness.conf`, such as one that `afe-init` configured,
`RALPH_MAX_ITERATIONS=5` and `REVIEW_MAX_ROUNDS=3` become 2; other values stay. Check by hand
what the update reports:

- `Warning: .claude/path-classes is not a default of the template`: remove its `approval` lines,
  and trim the ecosystem gate blocks to the files of your stack if you like.
- `Warning: docs/README.md is no longer maintained by the template`: it stays as a project file,
  and `scripts/check.sh` fails on its links and paths to removed files; update it, or delete it
  together with the links to it, such as those in `README.md`.
- `Warning: <path> names removed files (<names>); update or remove those references`: one line
  for each tracked file that is not template-owned, such as `README.md`, `.gitignore`, your
  decision records and documents, or the comments of a changed `.claude/harness.conf`, that
  still names a removed document or file. The update changes none of them.
