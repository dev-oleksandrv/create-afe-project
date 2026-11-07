---
status: proposed
date: 2026-11-07
decision-makers: dev-oleksandrv (repository owner)
scope: architecture
summary: "In the context of porting agent-docs-template 0.7.0, facing its move of the harness settings and path classes to .harness/, we decided to keep .claude/harness.conf and .claude/path-classes, and rejected the move to .harness/ and deferring the choice, to keep the paths every existing project uses, accepting a path translation in every later upstream port and a migration back into .claude/ for converted Copier projects."
supersedes: []
---

# Keep the harness files in .claude/ instead of upstream's .harness/

## Context and Problem Statement

agent-docs-template 0.7.0 (`xandronak/agent-docs-template`, changelog of 2026-11-05) moves the
seeded `.claude/harness.conf` and `.claude/path-classes` to `.harness/`, with a Copier
migration, because the scripts, hooks, and checks of every tool read them. Release 2.0.0 did not
port the move, and no document said why (the 2.0.0 review of 2026-11-06). Upstream 0.8.0 and
0.9.0 build on `.harness/`, for example `TEST_PLAN` in `.harness/harness.conf`. Where do the
harness files of a generated project live? The owner chose the option below in the review
session of 2026-11-06; accepting this record is the owner's step. The two other choices of that
port are [ADR 0004](0004-seed-the-gate-lines-of-every-ecosystem.md) and
[ADR 0005](0005-keep-documents-english-only.md).

## Considered Options

* Keep `.claude/harness.conf` and `.claude/path-classes`
* Move to `.harness/` with a migration and a fallback to `.claude/`, a MAJOR release
  ([`docs/maintaining.md`](../maintaining.md), section 4)
* Decide the location later

## Decision Outcome

Chosen option: "keep `.claude/`", because every existing project, hook, and check uses these
paths today and the move needs a MAJOR release. The ownership of both seeded files is in
[`docs/documentation-rules.md`](../documentation-rules.md), section 9.

Rejected: the move to `.harness/` (a MAJOR release and a migration in every project, now); a
later decision (the choice stays unrecorded while ports continue).

### Consequences

* Good, because existing projects and their own scripts keep the paths they name.
* Bad, because every later upstream port, 0.8.0 and 0.9.0 first, translates `.harness/` paths to
  `.claude/`; the location is revisited before 0.8.0 is ported.
* Bad, because a project from the Copier template 0.7.0 or later needs a migration that moves its
  `.harness/` files back into `.claude/` when it converts.

### Confirmation

Not checked yet: the migration is proposed on the branch `fix/copier-harness-conversion`, with a
test in `scripts/checks.d/10-template.sh` that confirms it once it merges. The owner's review
before the port of 0.8.0 confirms the location.
