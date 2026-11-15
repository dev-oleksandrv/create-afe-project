---
"create-afe-project": major
---

The template keeps what is true in a project and what an agent may not do; how an agent works on
a task (questions, plan, review, pull request) now comes from the developer's own setup, not from
the project. On the owner's decision of 2026-11-15: the process parts cost more per task than
they caught.

Removed, with the update removing the files:

- The skills `create-pr` and `review` with its rubric. A pull request is opened with `gh pr
  create`; `update-template` and `afe-init` do that themselves.
- Decision record statuses, their check `scripts/check-decisions.sh`, the generated index
  `docs/decisions/README.md` (`scripts/gen-decisions-index.sh`), and the `decisions` workflow
  with its jobs `integrity` and `readiness`. A record is accepted when it is written;
  `docs/decisions/adr-template.md` has `date`, `decided-by`, `scope`, `summary`, `supersedes`.
- Path classes (`scripts/lib/classes.sh`, `.claude/path-classes`), the "Gate files" section,
  the required sections of a pull request description, and the size warning.
- The Stop dispatcher `.claude/hooks/stop-dispatch.sh`, the green stamps
  (`scripts/lib/stamp.sh`), and `scripts/check.sh --if-changed`.
- The modules `acceptance_check` and `fail_without_change` with their scripts and workflow;
  their recorded answers are dropped.
- From `.claude/harness.conf`: `RALPH_MAX_ITERATIONS`, `REVIEW_MAX_ROUNDS`, `DIFF_WARN_LINES`,
  `ID_PATTERN`, `TEST_GLOBS`, `FWC_TOOLCHAIN_GLOBS`, `FWC_TEST`.

Changed:

- `AGENTS.md`: commands, limits, and two lines each for tests and documents. Its project block
  (now up to 20 lines) says how to run the product and see a change; `afe-init` writes that.
- `.claude/rules/testing.md` is eight rules; `.claude/rules/docs.md` says when a document
  changes: when a change makes a statement in it false, once, at the end.
- `.claude/risky-paths` (seeded) replaces `.claude/path-classes`: one glob per line for the
  paths where a mistake costs most. Nothing reads it but the agent.
- `scripts/check.sh` runs the project's checks, the link check, and the template integrity.
- `scripts/protect-branch.sh` requires the check `check` only; `--require-base` is gone.
- `review-code` (module `code_review`) holds its own criteria: errors of correctness and
  security against what the description says.

What a project must do:

- **Before merging the update**, the owner runs `scripts/protect-branch.sh` from the update's
  branch: the 4.x ruleset requires the check `integrity`, which no workflow reports any more,
  so every pull request, the update's included, would wait for it.
- The update turns the `high` globs of `.claude/path-classes` into `.claude/risky-paths` and
  removes the old file and a generated `docs/decisions/README.md`. It reports, as `Warning:`
  lines, the removed keys still set in `.claude/harness.conf` and each project file that names
  a removed file, such as a check that calls `scripts/check.sh --if-changed`.
- A Stop hook the project registered itself in `.claude/settings.project.json` keeps running;
  the template runs none.

Also in this release, from the audit of 2026-11-15:

- `guard.sh`: quoted text is not a command (it denied a harmless command in a real session);
  the command of `sh -c` and `eval` is; every push of a command is checked.
- `.env.example` is readable through the documented negation rule `Read(!.env.example)`; every
  other `.env*` file stays denied.
- The link check accepts a line range on a path (`src/x.ts:10-20`).
- CI review: the rules come from the base branch, the pull request's versions are data.
- `afe-init` asks about the sandbox and adds one smoke test per deployable part.
