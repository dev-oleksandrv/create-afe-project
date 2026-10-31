# Documentation map

Entry point for all documentation. Rules for agents: [`AGENTS.md`](../AGENTS.md). Formats,
statuses, ownership of files, and lifecycle: [`documentation-rules.md`](documentation-rules.md).
One fact has one owner document; every other document links to it instead of repeating it.

## What exists and which document owns which facts

| Kind of fact | Owner document | State |
| --- | --- | --- |
| Product name and purpose | [`README.md`](../README.md) | exists |
| The template itself: questions, settings, and the files a project receives | [`copier.yml`](../copier.yml) and [`template/`](../template/) | exists |
| How the template is changed, tested, versioned, and released | [`maintaining.md`](maintaining.md) | exists |
| What changed in each release | [`CHANGELOG.md`](../CHANGELOG.md) | exists |
| Agent rules: precedence, autonomy by risk, when a change is done, required checks | [`AGENTS.md`](../AGENTS.md) | exists |
| Environment commands: set up, check, fast check, end-to-end tests, reset | `scripts/env.sh` with `setup`, `check`, `fast`, `e2e`, or `reset` runs `.claude/harness.conf`: check `scripts/check.sh`, fast check `scripts/check-docs.sh`, end-to-end tests the template tests `scripts/checks.d/10-template.sh` ([`maintaining.md`](maintaining.md), section 3); setup and reset: not decided | check, fast check, and end-to-end tests exist |
| Documentation statuses, lifecycle, path classes and access, ownership of files, alignment, review checklist | [`documentation-rules.md`](documentation-rules.md) | exists |
| What a test is for and must prove, gates on tests | [`testing-rules.md`](testing-rules.md) | exists |
| Branches, commit messages, pull requests, template updates, review of pull requests | [`contributing.md`](contributing.md); applied in Claude Code by the skills `.claude/skills/create-pr/` and `.claude/skills/update-template/`, in CI by `.claude/skills/review-code/` | exists |
| Why a costly-to-reverse decision was made, and its status | [`decisions/README.md`](decisions/README.md), the generated index of short ADRs; other owner decisions are marked in their owner documents ([`documentation-rules.md`](documentation-rules.md), sections 3 and 5) | exists |
| Checks and enforcement | `scripts/check.sh` and the scripts it runs; Claude Code hooks and permissions `.claude/settings.json`, generated from `.claude/settings.project.json`, and `.claude/hooks/`; path classes `.claude/path-classes`; harness settings `.claude/harness.conf`; workflows `.github/workflows/`; metrics of merged pull requests `scripts/pr-metrics.sh` ([`documentation-rules.md`](documentation-rules.md), sections 7, 8, and 9) | exists |

## Planned sections

The documentation has a fixed set of sections ([`documentation-rules.md`](documentation-rules.md),
section 2). A planned section is created only when its first real content exists, through an
explicit change approved by the owner; this table is updated in the same change. Do not create
placeholder files.

| Kind of fact | Planned owner | Created when |
| --- | --- | --- |
| Requirements: what the system must do | `docs/requirements/`, one `REQ-NNN` per statement | the owner states the first requirement |
| Architecture: components, boundaries, runtime, code structure | `docs/architecture/` | the first design is proposed |
| Contracts: APIs, schemas, events | `contracts/` at the repository root, machine-readable and authoritative | the first interface is designed |
| Active plans | `docs/plans/` | work spans more than one session |
| Operations: run, deploy, observe, recover | `docs/operations/` | there is something to operate |
| Implemented behaviour | source code and its tests | the first code is merged |

## Reading order for a new agent

1. [`AGENTS.md`](../AGENTS.md)
2. This map
3. Only the documents the task needs, following links from here
