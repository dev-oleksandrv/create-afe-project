---
name: dual-review
description: Review the current branch with two independent reviewers, a Claude subagent and the Codex CLI in a read-only sandbox, against the review rubric of docs/contributing.md, fix their findings, and repeat for at most three rounds; produces the verdict for the pull request description. Use before opening a pull request that changes code, contracts, checks, or workflows.
allowed-tools: Read, Grep, Glob, Edit, Write, Agent, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(command -v codex), Bash(codex exec:*), Bash(scripts/check.sh)
---

# Dual review of a branch

Arguments: none, or the base branch (default `main`).

The rules are in `docs/contributing.md`, section 6, and `docs/testing-rules.md`. Read them first;
this skill applies them and does not restate them. It never commits, pushes, opens a pull
request, changes a status, or accepts a decision.

## Procedure

1. Scope: `git diff <base>...HEAD` plus the uncommitted changes (`git status --porcelain`,
   `git diff`). When they change nothing but documentation, stop: the dual review has no scope,
   and the verdict reads "not run: no code change". When the branch is a template update that
   changes only template-owned and generated files (`docs/contributing.md`, section 6), stop: the
   verdict reads "not run: template update to X.Y.Z".
2. Reviewer B must be able to run: `command -v codex`. When it is missing, stop before the first
   round and report "not run: Codex CLI unavailable". A second Claude reviewer never takes its
   place.
3. Gate: run `scripts/check.sh`. A round starts only when it passes; fix a failure first, as the
   author, and run it again.
4. Self-check, once, as the author, before the first round: compare every statement the diff
   adds or changes in a document with the code and the tests it describes
   (`docs/documentation-rules.md`, section 3), and compare the test plan
   (`docs/contributing.md`, section 3) with the tests. Correct a statement the code does not
   bear out, add a missing test, and name a case dropped from the plan with its reason; then run
   `scripts/check.sh` again.
5. Brief: write one file in the session's scratch directory, outside the repository, with the
   rubric of section 6 and its severity examples, the project's criteria (the owner document the
   map `docs/README.md` names under "Review criteria", when there is one),
   `docs/testing-rules.md`, the requirements or task the branch serves, the test plan, the diff, the final lines of `scripts/check.sh`, and
   these instructions: you review independently and have seen no
   other review; find problems, do not approve; judge what the checks cannot (whether the tests
   prove the requirement), not whether they pass; report only findings with a file, a line, a
   severity (`blocker`, `should`, `nit`, as section 6 defines them), and the rule; zero
   findings is a valid result; answer
   only with JSON `{"verdict": "PASS" | "FAIL", "findings": [{"severity", "file", "line",
   "criterion", "finding"}]}`, where any `blocker` or `should` means `FAIL`.
6. Round: run both reviewers at the same time, each with the same brief and nothing else.
   - Reviewer A: a fresh Claude subagent with the Agent tool, one per reviewer that the
     project's criteria name for the changed paths, and at least one. Their findings together
     are Reviewer A's verdict.
   - Reviewer B: `codex exec --sandbox read-only -C <repository root> - < <brief file>`, with
     the model of the Codex configuration; this skill pins none. A run that fails, times out,
     or returns no valid JSON is not a pass: stop and report it.
7. Verdict: both `PASS` ends the loop. A `nit` never fails a round: it is fixed or listed for
   the description, not reviewed again. Otherwise merge and deduplicate the `blocker` and
   `should` findings and fix only them, in the working tree, without commits and without changes the findings do not ask for.
   A finding you judge wrong is not fixed: it goes to the owner as a question, not argued away.
   Run `scripts/check.sh` until it passes, rewrite the brief from the new diff, and start the
   next round with fresh reviewers that know nothing of earlier rounds. From the second round
   the brief adds the decisions the owner made on this branch, each with its source (the pull
   request comment, or the chat instruction quoted with its date), and says that a decided point
   is not a finding. It adds nothing else: never the other reviewer's findings, and never the
   findings you declined or sent to the owner unanswered.
8. Stop after the third round that does not pass. The remaining findings become `blocking:` items
   of the pull request (`docs/contributing.md`, section 3).
9. Report the verdict in the form of the description's "Checks" item (section 3): passed or
   escalated, each reviewer's verdict and the model its tool reported, the number of rounds, the
   findings that only one reviewer raised, and the open questions. Name the files the fixes
   changed. Once the loop passes, the fixes are squashed into the branch's commits by section 2
   when the branch is committed; that is the author's step, not this skill's.
