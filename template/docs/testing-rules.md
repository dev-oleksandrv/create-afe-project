# Testing rules

Rules that every test in this repository follows, whatever its language or tools. `AGENTS.md`
holds the short rules and takes precedence if the two ever disagree. This file comes from the
project template: report such a disagreement to the template instead of editing it. The project
adds its test levels, tools, commands, thresholds, and the edge cases of its domain in its own
documents, which the map (`docs/README.md`) names, and its test checks in `scripts/checks.d/`
(`documentation-rules.md`, section 9).

## 1. What a test is for

- A test protects a behaviour that a requirement, an acceptance criterion, a contract, or a fixed
  defect names. It carries that identifier (`REQ-NNN`, `AC-NN`) in its name or a tag when one
  applies, so that an `implemented` status can point at it (`documentation-rules.md`, section 3).
- Test count and coverage are not goals. Coverage shows which lines ran, not what a test checked:
  it is a floor the project sets, never evidence of quality. Where the project runs mutation
  testing, the mutation score is the measure.
- What the type checker, schema validation, or the contract check already proves (a shape, a
  required field, a closed set of values) gets no test of its own.
- One behaviour has one test, or one parametrised test over its table of inputs. A test that
  catches nothing the other tests miss is removed, and removing it is a valid change.

## 2. How a test proves behaviour

- A test asserts an observable outcome: the returned value or result, the resulting state, or the
  emitted events, records, and output. An assertion that a mock was called, that a value is
  defined or truthy, or that nothing threw is not enough on its own.
- Fakes stand in for the boundaries of the unit under test (external services, storage, the
  clock, randomness), never for code inside it.
- Expected values are literals or fixtures. A test never computes its expectation with the logic
  it tests, and a snapshot is never the only assertion of a rule.
- Failure paths are tested as deliberately as success: every distinct outcome or error a unit can
  return has a test that produces it, and every invalid example of a contract is rejected where
  the input is validated.
- The edge cases that apply are covered: boundaries, empty and missing values, unknown against
  zero, duplicates and retries, concurrent use, time zones and period boundaries, and the largest
  input the requirement allows. The project lists the edge cases of its domain.
- Tests are deterministic: no sleeps, no real clock, no real network or external service, and no
  dependence on the order in which tests run.

## 3. Tests and the change they cover

- Tests come first: they are written before the implementation and run once to see them fail for
  the expected reason. A test that passes before the implementation exists tests nothing.
- The acceptance tests of a requirement's criteria are written or reviewed by someone other than
  the author of the implementation, before it exists; the author changes them only with the
  owner's agreement.
- A defect is fixed only after a regression test that reproduces it fails.
- Changing the expectation of an existing test is a change of behaviour: the pull request names
  the test and the requirement or owner decision behind the change.

## 4. Gates

- No test is skipped, focused, or deleted, no assertion is weakened, no code is excluded from
  coverage, and no threshold is lowered to make a check pass. Such a need is an open question for
  the owner.
- The quality measures the project records (coverage, mutation score) never fall below those of
  the base branch.
- The configuration of the test runner, coverage, mutation testing, and linters is listed in
  `.claude/protected-paths`, so that no agent loosens a gate without the owner.
- An invariant that must hold everywhere (for example, a secret never appears in output) is an
  executable check, a test or a project check, not only a sentence in a document.
