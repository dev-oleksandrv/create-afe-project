---
name: review
description: Review the current branch before its pull request opens, by the class of its changed paths - none for Markdown only, one reviewer and one round for normal and gate paths, two reviewers for high-risk paths for up to REVIEW_MAX_ROUNDS rounds - with the Codex CLI when it is installed, otherwise fresh Claude sub-agents, against the rubric in rubric.md; answer each finding and report the Checks line. Never commits, pushes, or opens a pull request. Use before opening a pull request.
allowed-tools: Read, Grep, Glob, Edit, Write, Agent, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(command -v codex), Bash(codex exec:*), Bash(scripts/check.sh:*), Bash(scripts/env.sh fast), Bash(scripts/check-decisions.sh:*)
---

# Review before the pull request

Arguments: none, or the base branch (default `main`).

The rubric is `.claude/skills/review/rubric.md`, next to this file; the testing rules are
`.claude/rules/testing.md`. Both go into the brief as they are, because a reviewer of another
model family does not load `.claude/rules/`. This skill never commits, pushes, or opens a pull
request. Suggestions never drive a loop; only blockers do, and only for `two`.

## Procedure

1. Scope: `scripts/check-decisions.sh --classes --base <base>` prints the class of every changed
   path and, last, `review<TAB>none|one|two`. For `none`, stop and report
   "Review: not run: Markdown only".
2. Reviewers: `command -v codex` tells whether the Codex CLI is installed.
   - `one`: the Codex CLI when it is installed, otherwise one fresh Claude sub-agent.
   - `two`: a fresh Claude sub-agent and the Codex CLI. Without Codex, two fresh Claude
     sub-agents, each with its own lens: the first reviews correctness and the blocker classes,
     the second the "Acceptance and test plan", the invariants, and the tests that should fail.
     The rounds: `REVIEW_MAX_ROUNDS` of `.claude/harness.conf`, default 2.
3. Brief: one file in the session's scratch directory, outside the repository, holding:
   - `.claude/skills/review/rubric.md` and `.claude/rules/testing.md`, pasted whole;
   - the project's own review criteria, pasted whole, when `AGENTS.md` names a file for them;
   - the task, and the "Acceptance and test plan": one line per identifier the change serves
     with its test files, or `None: <reason>`;
   - the diff: `git merge-base <base> HEAD`, then `git diff <merge-base>`, which includes
     uncommitted changes; and each untracked file that `git status --porcelain` lists, whole;
   - the last lines of the latest `scripts/check.sh` output of this session; run
     `scripts/check.sh --if-changed` when there is none;
   - for `two`, also `docs/invariants.md` when it exists, the reviewer's lens when both are
     Claude sub-agents, and the instruction that only objective criteria count: the blocker
     classes, the "Acceptance and test plan", and the invariants;
   - the instructions: review independently; find problems, do not approve; judge what the
     checks cannot; report only findings with a file, a line, a class (`blocker` or
     `suggestion`), and the criterion; zero findings is valid; answer only with JSON
     `{"verdict": "PASS" | "FAIL", "findings": [{"class", "file", "line", "criterion",
     "finding"}]}`, where a blocker means `FAIL`.
4. Run each reviewer with the brief and nothing else: a Claude sub-agent with the Agent tool,
   its prompt the brief; Codex, with the model of the Codex configuration, as
   `codex exec --sandbox read-only -C <repository root> - < <brief file>`. A run that fails,
   times out, or returns no valid JSON is not a pass: stop and report it.
5. Answers, once per finding. A suggestion is fixed now or declined with a reason. A blocker is
   fixed in the working tree or declined with a reason. After each set of fixes run
   `scripts/env.sh fast`.
   - `one`: a fresh reviewer of the same kind gets each fixed blocker with the finding and the
     fix diff only, and says whether the fix holds; nothing else is reviewed again.
   - `two`: after the fixes both reviewers review again, each from a fresh context with the
     same brief and the fix diff, until neither finds a blocker or `REVIEW_MAX_ROUNDS` rounds
     passed. Stop early when a blocker comes back unchanged after its fix, since another round
     will not settle it.
   A blocker still open at the end goes under "Open questions" of the pull request.
6. Report, for the pull request description:
   - The "Checks" line: `Review: <one|two>, <reviewer> (<model>)[, <reviewer> (<model>)],
     <rounds> round(s)`, with the model each reviewer reported.
   - Each finding: `<class> <file>:<line> (<criterion>, <reviewer>): <finding>. Answer: fixed |
     declined: <reason>`; and each open blocker for "Open questions".
   - The files the fixes changed; committing them is the caller's step.
