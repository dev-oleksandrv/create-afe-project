# Review rubric

The rubric of every review of this project, before and in a pull request. It is complete on its
own: a reviewer of any model family receives it in the brief, followed by the testing rules of
`.claude/rules/testing.md`, to which "the testing rules" below refers.

## Findings

- A review is a sensor, not a gate: the checks decide by themselves, and a reviewer judges what
  they cannot. Reviewers propose; the owner decides.
- A finding names a file, a line, a class, and the criterion it rests on; zero findings is valid,
  and style belongs to the linters.
- A `blocker`: merged as it is, the change breaks behaviour, a contract, security, or a product
  invariant (`docs/invariants.md`, when it exists), loses data, fails an item of its "Acceptance
  and test plan", or contradicts a higher source: `AGENTS.md`, an accepted decision record under
  `docs/decisions/`, a contract, or a requirement. Which bypass of a gate is a blocker follows
  section 4 of the testing rules. Any other finding is a `suggestion`.
- Each finding is answered once. A blocker is fixed, and the fix checked once more by a fresh
  reviewer given the blocker and the fix, or declined with a reason. A suggestion never drives a
  loop: it is fixed at once or declined with a reason.
- The project may add its own criteria in a file that `AGENTS.md` names; every reviewer applies
  both.

## Criteria

| Criterion | Passes when |
| --- | --- |
| Authority | every behaviour serves a named requirement or criterion, or is an open question; nothing is invented (`AGENTS.md`) |
| Co-change | contract, code, and tests change together; a breaking contract change is versioned; generated files are regenerated |
| Correctness | the logic does what the requirement says, with the edge cases that apply |
| Tests | the tests follow the testing rules, and every identifier of "Acceptance and test plan" has a test that carries it and fails without the change |
| Errors | no error is swallowed, no failure hides behind a default |
| Security | external input is validated where it enters; secrets never reach code, logs, or output |
| Dependencies | a new dependency exists in its registry under the name used, is maintained, has a license the project allows (an open question while no document says which), and does no job an existing dependency already does; its version is pinned exactly, through the lock file where the stack has one |
| Claims | nothing is described as working without a test |
