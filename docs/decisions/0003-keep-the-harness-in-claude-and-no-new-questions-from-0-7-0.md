---
status: proposed
date: 2026-11-06
decision-makers: dev-oleksandrv (repository owner)
scope: architecture
summary: "In the context of porting agent-docs-template 0.7.0, facing its move of the harness files to .harness/ and its new questions ecosystems and docs_language, we decided to keep .claude/harness.conf and .claude/path-classes, seed the gate lines of every ecosystem, and keep documents English-only, and rejected the move to .harness/, the two questions, and deferring the choice, to keep existing projects and the wizard unchanged, accepting a path translation in every later upstream port."
supersedes: []
---

# Keep the harness in .claude/ and add no question from agent-docs-template 0.7.0

## Context and Problem Statement

Release 2.0.0 ported agent-docs-template 0.7.0 (`xandronak/agent-docs-template`, changelog of
2026-11-05) except three changes, and no document said why (the 2.0.0 review of 2026-11-06):
the move of `.claude/harness.conf` and `.claude/path-classes` to `.harness/`, with a Copier
migration; the question `ecosystems`, which seeds the gate lines of each chosen ecosystem; and
the question `docs_language`. Upstream 0.8.0 and 0.9.0 build on `.harness/`, for example
`TEST_PLAN` in `.harness/harness.conf`. Where do the harness files live, and which of the two
questions does the wizard of [`src/config.js`](../../src/config.js) adopt? The owner chose the
options below in a review session on 2026-11-06; accepting this record is the owner's step.

## Considered Options

* Keep `.claude/`, seed the gate lines of every ecosystem, keep documents English-only
* Move to `.harness/` with a migration and a fallback to `.claude/`, a MAJOR release
  ([`docs/maintaining.md`](../maintaining.md), section 4)
* Decide the location later
* Port the `ecosystems` question, or let the `afe-init` skill add the lines of the stack
* Port the `docs_language` question

## Decision Outcome

Chosen option: "keep `.claude/`, seed every ecosystem, English-only", because the files keep the
paths every existing project, hook, and check uses today, upstream's default for `ecosystems`
is all of them, and [`AGENTS.md`](../../AGENTS.md), section 5, requires every document in
English. The ownership of both seeded files is in
[`docs/documentation-rules.md`](../documentation-rules.md), section 9.

Rejected: the move to `.harness/` (a MAJOR release and a migration in every project, now); a later
decision (the three choices stay unrecorded); the `ecosystems` question (a stack left out gets no
gate on its manifests); `afe-init` (the lines depend on an agent run, not on the seeded file);
`docs_language` (it contradicts `AGENTS.md`, section 5).

### Consequences

* Good, because existing projects and their own scripts keep the paths they name.
* Good, because a manifest or lock file of the ten ecosystems of upstream 0.7.0 is class gate,
  with no question.
* Bad, because every later upstream port, 0.8.0 and 0.9.0 first, translates `.harness/` paths to
  `.claude/`; the location is revisited before 0.8.0 is ported.
* Bad, because a project from the Copier template 0.7.0 or later needs a migration back into
  `.claude/` on conversion, and loses a `docs_language` other than English, with a warning.

### Confirmation

Not checked yet: the migration and the warning are proposed on the branch
`fix/copier-harness-conversion`, the ecosystem gate lines on `feat/ecosystem-gate-lines`; their
tests in `scripts/checks.d/10-template.sh` confirm the decision once they merge. The owner's
review before the port of 0.8.0 confirms the location.
