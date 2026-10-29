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
| Agent rules: precedence, boundaries, required checks | [`AGENTS.md`](../AGENTS.md) | exists |
| Documentation statuses, lifecycle, ownership of files, alignment, review checklist | [`documentation-rules.md`](documentation-rules.md) | exists |
| Branches, commit messages, pull requests, template updates | [`contributing.md`](contributing.md); applied in Claude Code by the skills `.claude/skills/create-pr/` and `.claude/skills/update-template/` | exists |
| Why a costly-to-reverse decision was made, and its status | [`decisions/README.md`](decisions/README.md), the generated index of short ADRs; other owner decisions are marked in their owner documents ([`documentation-rules.md`](documentation-rules.md), sections 3 and 5) | exists |
| Checks and enforcement | `scripts/check.sh` and the scripts it runs; Claude Code hooks `.claude/settings.json`, `.claude/hooks/`; workflows `.github/workflows/` ([`documentation-rules.md`](documentation-rules.md), sections 7 and 9) | exists |

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
