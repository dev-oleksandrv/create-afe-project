# Testing rules

Rules that every test in this repository follows, whatever its language or tools. `AGENTS.md`
holds the short rules and takes precedence if the two ever disagree. This file comes from the
project template: report such a disagreement to the template instead of editing it. The project
adds the levels of its verification ladder (static checks, unit, integration, user journeys),
tools, commands, thresholds, and the edge cases of its domain in documents the map names, and
its test checks in scripts/checks.d/ (`documentation-rules.md`, section 9).

## 1. What a test is for

- A test protects a behaviour that a requirement, an acceptance criterion, a contract, or a fixed
  defect names. It carries that identifier (`REQ-NNN`, `AC-NN`) in its name or a tag when one
  applies, so that an `implemented` status and the "Acceptance and test plan" of a pull request can
  point at it (`documentation-rules.md`, section 3; `contributing.md`, section 3). The project's
  checks in scripts/checks.d/ map each identifier to the tests that carry it.
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
  return has a test that produces it; every invalid contract example is rejected where input is validated.
- The edge cases that apply are covered: boundaries, empty and missing values, unknown against
  zero, duplicates and retries, concurrent use, time zones and period boundaries, and the largest
  input the requirement allows. The project lists the edge cases of its domain.
- Tests are deterministic: no sleeps, no real clock, network, or external service, no dependence on
  test order. A flaky test teaches that red can be ignored: it is fixed, never retried or rerun
  until green; skipping it is a blocker of section 4 unless the owner, asked, decides otherwise.

## 3. Tests and the change they cover

- Tests come first: they are written before the implementation and run once to see them fail for
  the expected reason. A test that passes before the implementation exists tests nothing.
- The acceptance tests of a requirement's criteria are written or reviewed by someone other than
  the author of the implementation, before it exists; the author changes them only with the
  owner's agreement.
- The agent derives the test plan from the identifiers the change serves: their cases, failure
  paths, and edge cases (section 2). It is a report under "Acceptance and test plan"
  (`contributing.md`, section 3), never approved per pull request and not maintained afterwards.
  Each new or changed test fails on the base and passes with the change.
- A defect is fixed only after a regression test that reproduces it fails.
- A refactoring keeps the tests as they are. A change of behaviour first changes the requirement
  or the acceptance criterion, then the test that carries the same identifier; the pull request
  names both.

## 4. Gates

- No test is skipped, focused, or deleted, no assertion is weakened, no code is excluded from
  coverage, and no threshold is lowered to make a check pass. Such a need is an open question for
  the owner.
- The quality measures the project records (coverage, mutation score) never fall below those of
  the base branch.
- The configuration of the test runner, coverage, mutation testing, and linters is class gate in
  `.claude/path-classes` (`documentation-rules.md`, section 8): it changes without a prompt, the
  pull request lists it under "Gate files", which the readiness check enforces, and the owner
  reviews it after the merge.
- An invariant that must hold everywhere (for example, a secret never appears in output) is an
  executable check, a test or a project check, and the register docs/invariants.md names it
  with that check (`documentation-rules.md`, section 2); its invariants are criteria of the
  review of class high (`contributing.md`, section 6).
- Threat model of development gates: a gate (a lint rule, a test check, a coverage or mutation
  setting, an agent hook) catches honest mistakes and shortcuts; it is not a security boundary.
  It decides which bypass is a `blocker` (`contributing.md`, section 6): a diff that itself
  loosens or evades a gate (a test skipped, an assertion weakened, a threshold lowered, a test
  behind an aliased import), and any bypass of a product invariant (security, secrets, policy
  enforcement, limits), whatever it takes. A gap that only deliberate evasion exploits, such as
  a computed property or tampering with a gate's own state, is a `suggestion`.
