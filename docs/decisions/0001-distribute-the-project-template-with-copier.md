---
status: accepted
date: 2026-10-29
decision-makers: xandronak (repository owner)
scope: operations
summary: "In the context of a template that every new project starts from and that keeps changing, facing projects that must receive later fixes without losing their own content, we decided to distribute it with Copier, versioned by Git tags, and rejected a GitHub template repository, a Claude Code plugin, and a Git submodule, to update projects by a three-way merge, accepting Copier and trusted tasks as a dependency."
supersedes: []
---

# Distribute the project template with Copier, versioned by Git tags

## Context and Problem Statement

Every new project starts from this template, and the template keeps changing after projects
exist. A project must receive later fixes without losing its own content, and must record which
version it follows. Which mechanism creates projects and updates them?

## Considered Options

* Copier: questions in `copier.yml`, a recorded `.copier-answers.yml`, `copier update` with a
  three-way merge, versions from Git tags
* A GitHub template repository
* A Claude Code plugin with the skills and hooks
* A Git submodule or subtree with the shared files

## Decision Outcome

Chosen option: "Copier", because it alone both creates a project from answers and updates it
later by merging the template's change with the project's own edits, and it records the version a
project follows. Versions are Git tags; the policy and the release procedure are owned by
[`docs/maintaining.md`](../maintaining.md), sections 4 and 5.

Rejected: a GitHub template repository (one copy, no update path); a Claude Code plugin (it does
not own repository files, and CI cannot see it); a submodule or subtree (the shared files would
live in a separate tree that the rules, the links, and the checks of the project cannot address as
their own).

### Consequences

* Good, because a fix in the template reaches every project as a reviewed pull request.
* Bad, because updating needs Copier, and the template's tasks need `--trust`.
* Bad, because a project that edits a template-owned file gets merge conflicts; the ownership
  check makes such an edit fail before it spreads.

### Confirmation

`scripts/checks.d/10-template.sh` renders the template with Copier on every pull request; the
`release` workflow publishes only tags with a changelog section.
