# AGENTS.md

Instructions for AI coding agents in this repository; people start at `README.md`. This file
comes from the project template: change it in the template, except the project block below.

<!-- project:start -->
The project is **agent-docs-template**: the Copier template for agent-friendly repositories
(`xandronak/agent-docs-template`). The product is `template/` with `copier.yml`. This repository's
own template-owned files are generated from `template/` by `scripts/sync-self.sh`: edit
`template/`, then sync; never edit the generated copies. `docs/contributing.md`, section 5, and the
`update-template` skill do not apply here. Maintainer rules: `docs/maintaining.md`.
<!-- project:end -->

## 1. Sources of truth and precedence

Each fact has exactly one owner document; `docs/README.md` lists which document owns which kind
of fact. When sources disagree, the higher item below wins; the lower one is wrong and must be
fixed or flagged:

1. Explicit instructions from the user in the current conversation.
2. `AGENTS.md` (this file), `docs/documentation-rules.md`, `docs/contributing.md`: process rules.
3. Owner decisions: `accepted` ADRs, and statements marked `Decided by the owner` in owner documents.
4. Contracts (machine-readable schemas) for interfaces.
5. Requirements in `docs/requirements/`.
6. Source code and its tests: the only proof of *implemented* behaviour.
7. Everything else is non-authoritative: plans, research notes, chat history, agent reports.

## 2. Where to look

Read on demand. Do not load the whole `docs/` tree.

- `docs/README.md`: documentation map, what exists and what is planned. Read it first.
- `docs/documentation-rules.md`: status vocabulary, lifecycle, ownership of files, alignment with
  code and contracts, review checklist. Read it before creating or changing any document.
- `docs/decisions/README.md`: generated index of ADRs; open a record only when the task needs it.
- `docs/plans/`: active plans only.
- `docs/contributing.md`: branches, commit messages, pull requests. Read it before you commit.

## 3. Status of information

Every statement about the system has exactly one status, and the status must be visible:

| Status | Meaning | Who sets it |
| --- | --- | --- |
| requirement | what the system must do; not a promise that it is built | owner (agents may draft) |
| proposed | a suggested decision or design; may be rejected | anyone, including agents |
| accepted | a decision the owner approved | owner only |
| implemented | behaviour present in merged code with tests | code and tests, never prose |

The repository owner is the only decision-maker. Agents, skills, and subagents propose; they never
decide.
Never present a plan, a proposal, or your own design as something that exists
(`documentation-rules.md`, section 3).

## 4. Boundaries for autonomous decisions

Allowed without asking:

- Do the task as stated and make routine implementation choices within it.
- Fix typos, broken links, lint errors, and inconsistencies, except in template-owned files.
- Update the owner document in the same change when your change alters documented behaviour,
  a contract, or an operational procedure.
- Propose a needed decision as a `proposed` ADR or an edit (`documentation-rules.md`, section 5).

Not allowed without an explicit user instruction:

- Inventing requirements, defaults, or decisions. Missing information is an open question, not a
  default. An unavoidable assumption is labelled "assumption" where used and in your report.
- Accepting any decision or marking it decided, or calling anything `implemented` without tests.
- Changing the documentation map or the directory structure; adding a section, tool, dependency,
  or CI job. A template-owned file changes only in the template: even on instruction, a local edit
  fails `scripts/check-template.sh`, so propose the change to the template instead.
- Deleting, archiving, or superseding documents, except a plan that your own task completes.
- Using any ADR format or location other than `docs/decisions/adr-template.md`.

## 5. Documentation change rules

- All documents are written in English, without exception.
- Change a document only when the task changes the facts it owns; link, never copy.
- ADRs on `main` are immutable except their status line; supersede, never rewrite.
- Research, logs, transcripts, and agent reports never go into `docs/`. They stay in the
  conversation, the PR description, or scratch space until a person promotes durable facts.
- Structure and rule changes are separate, owner-approved changes, never bundled with other work.

## 6. Required checks

- Before you finish, run `scripts/check.sh` and make it pass: documentation (markdownlint-cli2
  and lychee), decision records, template integrity, and the project's own checks in
  `scripts/checks.d/`. Do not disable rules or exclude files to get a pass.
- Semantic self-review, which tools cannot do: statuses correct, no invented fact, no duplication,
  map and links updated. Checklist: `docs/documentation-rules.md`, section 7.
- In Claude Code, Stop hooks rerun the documentation, decision, and template checks and the
  project's own Stop hooks; a protect hook asks the owner before edits of protected files. Pull
  requests get a readiness check (`contributing.md`, section 3) and `docs-review` proposals.
- Finish with a report: files changed, checks with results, assumptions, open questions, readiness.
