---
status: proposed
date: 2026-11-07
decision-makers: dev-oleksandrv (repository owner)
scope: process
summary: "In the context of porting agent-docs-template 0.7.0, facing its docs_language question for documents, commit messages, and pull requests, we decided to keep documents English-only and not adopt the question, and rejected porting it, to keep the rule of AGENTS.md section 5, accepting that a converted Copier project with another language loses that answer, with a warning."
supersedes: []
---

# Keep documents English-only and do not adopt docs_language

## Context and Problem Statement

agent-docs-template 0.7.0 (`xandronak/agent-docs-template`, changelog of 2026-11-05) adds the
question `docs_language` (English by default) for a project's documents, commit messages, and
pull requests. Release 2.0.0 did not port it, and no document said why (the 2.0.0 review of
2026-11-06), while [`AGENTS.md`](../../AGENTS.md), section 5, says all documents are written in
English, without exception. Does the wizard of [`src/config.js`](../../src/config.js) ask for a
language? The owner chose the option below in the review session of 2026-11-06; accepting this
record is the owner's step. Related: [ADR 0003](0003-keep-the-harness-files-in-claude.md),
whose conversion of a Copier project also handles this answer.

## Considered Options

* Keep documents English-only; do not adopt `docs_language`
* Port the `docs_language` question

## Decision Outcome

Chosen option: "English-only", because `AGENTS.md`, section 5, already requires it and the
wizard needs no new question.

Rejected: porting the question (it contradicts `AGENTS.md`, section 5).

### Consequences

* Good, because the rule documents and every generated project use one language.
* Bad, because a team that writes in another language cannot choose it.
* Bad, because a project from the Copier template 0.7.0 or later with a `docs_language` other
  than English loses that answer when it converts, with a warning.

### Confirmation

Not checked yet: the warning is proposed on the branch `fix/copier-harness-conversion`, with a
test that confirms it once it merges. `AGENTS.md`, section 5, holds the rule.
