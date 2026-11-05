# Contribution rules

Branches, commits, pull requests, when a change is done, template updates, and review.
`AGENTS.md` takes precedence; this file comes from the template, so report a disagreement there.
Everything written into git history and pull requests is in English, without exception.

## 1. Branches

- `main` on the remote `origin` (`git remote set-head origin -a`) is the only long-lived branch
  and the base of every pull request; nothing but the template's initial commit goes to it directly.
- A working branch is named `<type>/<slug>`: `docs` for documentation, decisions, requirements,
  and plans; `ci` for checks, hooks, workflows, and skills; `feat` for new behaviour; `fix` for a
  defect; `chore` for tooling and housekeeping. The slug names the change in two to five
  lowercase words joined by `-`, such as `ci/check-script-timeout`; no ticket numbers.
- One branch carries one logical change and ends in one pull request: one mechanism with its
  tests and the owner documents it changes (one check, one hook, one rule, one behaviour). A rule
  change and the first code that follows it are two changes (`AGENTS.md`, section 5); readiness
  warns above `DIFF_WARN_LINES` changed lines. An exception needs the owner's instruction, named
  under "Notes for the owner".
- Each parallel session works in its own git worktree (`git worktree add`) on its own branch. A
  session that stops unfinished leaves a checkpoint: its commits pushed, and its progress and
  blockers in the plan or the pull request description, where the next session starts.
- A branch that a tool named otherwise (`claude/<name>`) is renamed before its first push; a
  pushed one keeps its name, noted under "Notes for the owner". After the merge GitHub deletes it, a repository
  setting that `scripts/protect-branch.sh` applies.

## 2. Commits

- The subject line is `<Scope>: <summary>`, at most 72 characters.
  - `Scope` names what the commit changes, as it is written elsewhere: an owner document or its
    area (`Requirements`, `Rules`, `Map`, `Plan`, `Contributing`), a decision (`ADR-0001`), a
    workflow or skill (`create-pr`). Several scopes are separated by commas.
  - `summary` states what the commit does or what is now true, in the present tense, lowercase,
    without a trailing period: `apply review fixes`, `requirements section now exists`.
- The body, after a blank line and wrapped at 72 characters, says why when the subject does not,
  and names the documents affected, the statuses changed and who set them, and related pull
  requests (`PR #2`). It never calls something implemented without a test.
- One commit per logical change. Work-in-progress and fix-up commits are squashed before the
  branch is pushed. A follow-up that answers review is its own commit.
- A commit authored by an agent ends with the co-author trailer its tool prescribes; for Claude
  Code, a `Co-Authored-By:` line naming the model.

## 3. Pull requests and done

- One pull request per branch, against `main`; a draft while the work is unfinished or a check
  other than merge readiness fails. The title is the branch's commit subject, or one subject in
  the same form for several commits.
- The description is the report of `AGENTS.md`, section 6: the evidence that the change is done.
  It has these sections in this order; "Owner decisions" and "Gate files" appear when they have
  an item, "Notes for the owner" is optional, and an empty section reads "None".

```markdown
## Summary

- What changed and why, one bullet per owner document or area, naming the files; each new
  statement with its status (`proposed`, `accepted by the owner`, `implemented` with its test).

## Acceptance and test plan

- One bullet per identifier the change serves (`REQ-NNN`, `AC-NN`, or an identifier in the owner
  document of a check): its cases, the test files in backticks and the tests that carry it, and
  the evidence: failed on the base and why, passes now. "None: <reason>" for no behaviour change.

## Checks

- `scripts/check.sh` passes; or, for each failing part, the command and the lines of its output
  that show the failure, so that the next session can resume from them.
- Semantic self-review (`docs/documentation-rules.md`, section 7): what was checked, the result.
- The review before the pull request (section 6): its reviewers and their models, or why none.

## Assumptions and open questions

- None, or one bullet each, labelled `blocking:`, `recorded:`, `assumption:`, or `limit:`.

## Owner decisions

- Each `Decided by the owner` marker the branch adds: the file, the statement, and the owner's
  instruction, quoted with its date.

## Gate files

- Each file of class gate the branch touches, as `scripts/check-decisions.sh --ready` lists them.

## Metrics

| Sensor | Class | Found | Fixed | Limit | Declined |
| --- | --- | --- | --- | --- | --- |
| check.sh | blocker | 0 | 0 | 0 | 0 |

| Measure | Value |
| --- | --- |
| First check.sh | pass |
| Ralph iterations | 1 |
| Santa rounds | 0 |
| Owner interventions | 0 |
| Files outside the scope | 0 |
| Regression of | none |

## Notes for the owner

- Optional: protected files touched and the instruction that allowed it, alternatives not taken.
```

- An agent's pull request ends with the attribution line its tool prescribes; for Claude Code,
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- The labels of "Assumptions and open questions":
  - `blocking:` a question about the pull request itself (its content, a status, a decision it
    needs), resolved before the merge. A review finding is one only in a Santa loop (section 6).
  - `recorded:` a question about the subject matter, kept with an identifier in its owner
    document, which the item names (`recorded: OQ-1 in docs/requirements/<document>.md`).
  - `assumption:` an assumption the change rests on, also labelled where it is used.
  - `limit:` a suggestion of a review that the branch does not fix, with its sensor and reason;
    for a check, its owner document now names the forms it catches. The merge accepts it.
- A change is done when each identifier it serves has a test that carries it, each new or changed
  test failed on the base and passes now, `scripts/check.sh` passes and no measure the project
  records falls below the base, no `blocker` is open, and the readiness check passes. The agent
  derives the test plan from the identifiers (`testing-rules.md`, section 3); it is a report,
  never approved per pull request and not maintained afterwards.
- Ralph loop: the author runs `scripts/check.sh`, fixes, and runs it again until it passes, at
  most `RALPH_MAX_ITERATIONS` runs (`.claude/harness.conf`, default 5). At the cap the author
  stops and reports the failing command and its output. Metrics count the runs.
- An agent writes a `Decided by the owner` marker only on the owner's instruction and lists each
  one it adds under "Owner decisions"; the owner's merge confirms them.
- Metrics measure the sensors, so that a rule or check that never fires is removed;
  `scripts/pr-metrics.sh` aggregates merged pull requests, with the time to merge. A sensor is a
  check or a reviewer; an owner intervention is anything the owner answered, approved, or
  corrected besides the merge; "Regression of" names the pull request whose behaviour this repairs.
- Ready to merge: `scripts/check-decisions.sh --ready` and every other check pass, no `blocker`
  is open, every finding is answered. Readiness fails on a missing "Acceptance and test plan" or
  "Metrics" section, a missing or repeated measure; an added record still `proposed`; an
  open `blocking:` item or one without a label; an Acceptance item that is neither "None" with a
  reason nor names an existing path in backticks; an added marker in a Markdown file or a touched
  gate file that its section does not name; a Metrics table outside its forms, whose answers do
  not add up, or with a blocker as a limit. Whether a test proves
  its identifier is left to the review. The `decisions` workflow runs it on every change and
  does not block. A pull request waiting only on the owner stays open as "not ready to merge".
- The owner merges with a merge commit; `scripts/protect-branch.sh` allows no other merge method.

## 4. Before opening a pull request

Sections 1 to 3 hold, the checks pass or their failures are stated, and every affected owner
document is updated in the same branch. The `create-pr` skill runs this and opens it.

## 5. Template updates

The template-owned files (`documentation-rules.md`, section 9) change only through an update to a
template version, which `.afe-answers.json` records; the `update-template` skill runs it:

1. From an up-to-date `main`, on the branch `chore/template-update`: `npx create-afe-project@latest
   update --defaults`, or `@<version>`. It replaces the template-owned files, keeps the project
   block of `AGENTS.md`, never changes an existing seeded file, and regenerates generated files.
2. Review its report: a replaced local edit of a template-owned file is lost unless it moves to
   the template; project files are untouched. An update changes seeded files only by a migration
   the changelog names.
3. `scripts/check.sh`, then a pull request `Template: update to <version>` with the changelog
   entries since the previous version under "Summary". A change the project needs in a
   template-owned file is made in the template first.

## 6. Review of pull requests

- AI review is a sensor, not a gate: the checks decide by themselves, and a reviewer judges what
  they cannot. Reviewers propose; the owner decides. The review follows the highest class of the
  changed paths (`documentation-rules.md`, section 8), as `scripts/check-decisions.sh --classes`
  prints it. Before the pull request the `create-pr` skill runs it:
  - low (documents, generated files, a template update): no reviewer;
  - normal and gate: one pass by one reviewer, a fresh
    Claude subagent; only the fix of a blocker is checked again;
  - high: one pass as for normal; the Santa loop is an optional module of the template.
- In the pull request, `docs-review` reviews every pull request and `code-review` every one that changes code, contracts, checks, or workflows, once, when it
  opens or leaves draft; a push does not run them again.
- A finding names a file, a line, a class, and the rule it rests on; zero findings is valid, and
  style belongs to the linters. A `blocker`: merged as it is, the change breaks behaviour, a
  contract, security, or a product invariant (`docs/invariants.md`), loses data, fails an item of
  its Acceptance section, or contradicts a higher source (`AGENTS.md`, section 1). Which bypass of
  a gate is a blocker follows `testing-rules.md`, section 4. Any other finding is a `suggestion`.
- Each finding is answered once. A blocker is fixed, and the fix checked once more by a fresh
  reviewer given the blocker and the fix, or declined with a reason. A suggestion never drives
  a loop: it is fixed at once, recorded as `limit:` (section 3), or declined with a reason.
- The project adds its own criteria in one owner document that the map names under "Review
  criteria"; every reviewer applies both.

| Criterion | Passes when |
| --- | --- |
| Authority | every behaviour serves a named requirement or criterion, or is an open question; nothing is invented (`AGENTS.md`, section 4) |
| Co-change | contract, code, tests, and owner document change together; a breaking contract change is versioned; generated files are regenerated |
| Correctness | the logic does what the requirement says, with the edge cases that apply |
| Tests | the tests follow `docs/testing-rules.md`, and every identifier of "Acceptance and test plan" has a test that carries it and fails without the change |
| Errors | no error is swallowed, no failure hides behind a default |
| Security | external input is validated where it enters; secrets never reach code, logs, or output |
| Dependencies | a new dependency exists in its registry under the name used, is maintained, has a license the project allows (an open question while no document says which), and does no job an existing dependency already does; its version is pinned exactly, through the lock file where the stack has one |
| Statuses | nothing is called implemented without a test (`documentation-rules.md`, section 3) |

- A defect found after the merge is fixed after a regression test; its pull request gives the
  evidence pack (the reproduction, the root cause, the regression test failing then passing) and
  names what keeps the next one out: a criterion, a check, a rule, or why none fits.
