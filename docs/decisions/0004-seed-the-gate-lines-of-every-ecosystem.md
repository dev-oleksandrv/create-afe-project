---
status: proposed
date: 2026-11-07
decision-makers: dev-oleksandrv (repository owner)
scope: process
summary: "In the context of porting agent-docs-template 0.7.0, facing its ecosystems question that seeds the gate lines of each chosen ecosystem, we decided to seed the gate block of every ecosystem in .claude/path-classes without a question, and rejected the question and lines added by afe-init, to make the manifests and lock files of any supported stack class gate, accepting blocks for ecosystems a project does not use."
supersedes: []
---

# Seed the gate lines of every ecosystem instead of asking for them

## Context and Problem Statement

agent-docs-template 0.7.0 (`xandronak/agent-docs-template`, changelog of 2026-11-05) adds the
question `ecosystems` (node, python, go, rust, jvm, ruby, php, dotnet, swift, dart; all by
default). Its seeded path classes list the gate files of each chosen ecosystem as a block.
Release 2.0.0 ported neither, and no document said why (the 2.0.0 review of 2026-11-06). So in a
JVM, Ruby, PHP, .NET, Swift, Dart, Bun, or Deno project a manifest or lock file is class normal
and never appears under "Gate files". How does a project get the gate lines of its stack? The
owner chose the option below in the review session of 2026-11-06; accepting this record is the
owner's step. Related: [ADR 0003](0003-keep-the-harness-files-in-claude.md), the location of
the file.

## Considered Options

* Seed the block of every ecosystem in `.claude/path-classes`, without a question
* Port the `ecosystems` question
* The `afe-init` skill adds the lines of the project's stack

## Decision Outcome

Chosen option: "seed every block", because upstream's default for `ecosystems` is all of them
and the wizard of [`src/config.js`](../../src/config.js) needs no new question. The classes and
the review they need are in [`docs/documentation-rules.md`](../documentation-rules.md),
section 8.

Rejected: the question (a stack left out gets no gate on its manifests); `afe-init` (the lines
depend on an agent run, not on the seeded file).

### Consequences

* Good, because a manifest or lock file of any of the ten ecosystems is class gate, with no
  question.
* Bad, because the file holds blocks for ecosystems the project does not use.
* Bad, because an update never changes a seeded file, so an existing project copies the blocks
  by hand.

### Confirmation

Not checked yet: the blocks are proposed on the branch `feat/ecosystem-gate-lines`, with a test
in `scripts/checks.d/10-template.sh` that confirms them once it merges.
