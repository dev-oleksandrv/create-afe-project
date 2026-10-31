---
name: dual-review
description: Review the current branch before its pull request opens, by the class of its paths (docs/contributing.md, section 6) - none for class low, one pass by one reviewer for normal and gate, the Santa loop of two independent reviewers (a Claude subagent and the Codex CLI, or two fresh Claude subagents without Codex) for high, up to REVIEW_MAX_ROUNDS rounds - and answer each finding; produces the Checks line and the Metrics rows for the pull request description. Use before opening a pull request.
allowed-tools: Read, Grep, Glob, Edit, Write, Agent, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(command -v codex), Bash(codex exec:*), Bash(scripts/check.sh), Bash(scripts/check-decisions.sh:*)
---

# Review before the pull request

Arguments: none, or the base branch (default `main`).

The rules are in `docs/contributing.md`, section 6, and `docs/testing-rules.md`. Read them first;
this skill applies them. It never commits, pushes, opens a pull request, changes a status, or
accepts a decision. Suggestions never drive a loop; only blockers of class high do.

## Procedure

1. Scope: `scripts/check-decisions.sh --classes --base <base>` prints the class of every changed
   path and, last, `review<TAB>none|one|santa`. For `none`, stop: "Review: not run: class low".
2. Reviewers: `command -v codex` tells whether the Codex CLI is installed.
   - `one`: the Codex CLI when it is installed, otherwise one fresh Claude subagent.
   - `santa`: a fresh Claude subagent and the Codex CLI. Without Codex, a second fresh Claude
     subagent takes its place, with another lens: the first reviews correctness and the blocker
     classes, the second the Acceptance criteria, the invariants, and the tests that should fail;
     "Checks" names both. The rounds: `REVIEW_MAX_ROUNDS` of `.claude/harness.conf`, default 3,
     never more than 5.
3. Gate: `scripts/check.sh` passes (the Ralph loop of `docs/contributing.md`, section 3). Then the
   author's self-check: compare each statement the diff adds in a document with the code and the
   tests it describes, and each identifier of "Acceptance and test plan" with the tests that
   carry it; fix what does not hold and run `scripts/check.sh` again.
4. Brief: one file in the session's scratch directory, outside the repository: the rubric and
   the classes of section 6, the project's criteria (the owner document the map names under
   "Review criteria"), `docs/testing-rules.md`, the task or requirements, "Acceptance and test
   plan", the diff, and the last lines of `scripts/check.sh`. For `santa` also `docs/invariants.md`
   when it exists, and the instruction that only objective criteria count: the blocker classes,
   the Acceptance criteria, and the invariants. Instructions to the reviewer: review
   independently; find problems, do not approve; judge what the checks cannot; report only
   findings with a file, a line, a class (`blocker` or `suggestion`), and the rule; zero findings
   is valid; answer only with JSON `{"verdict": "PASS" | "FAIL", "findings": [{"class", "file",
   "line", "criterion", "finding"}]}`, where a blocker means `FAIL`.
5. Run each reviewer with the same brief and nothing else: a Claude subagent with the Agent tool;
   Codex with `codex exec --sandbox read-only -C <repository root> - < <brief file>`, the model of
   the Codex configuration. A run that fails, times out, or returns no valid JSON is not a pass:
   stop and report it.
6. Answers, once per finding: a suggestion is fixed now or written up for `limit:` with its
   reason, or declined with the rule it misreads. A blocker is fixed in the working tree or
   declined with a reason.
   - `one`: a fresh reviewer of the same kind gets each fixed blocker and the fix diff only, and
     says whether the fix holds; nothing else is reviewed again.
   - `santa`: after the fixes both reviewers review the branch again, each from a fresh context
     with the same brief and the fix diff, until neither finds a blocker. Stop early when a
     blocker comes back unchanged after its fix, since another round will not settle it. After
     the last round the open blockers become `blocking:` items.
   Run `scripts/check.sh` after each set of fixes.
7. Report, in the form of the description (`docs/contributing.md`, section 3): the Checks line
   with the reviewers, the model each tool reported, and the rounds; each finding with its
   class, reviewer, and answer; the `limit:` items; one Metrics row per reviewer and class, such
   as `| dual-review/codex | suggestion | 2 | 1 | 1 | 0 |`; and the Santa rounds. Name the files
   the fixes changed; committing them is the author's step.
