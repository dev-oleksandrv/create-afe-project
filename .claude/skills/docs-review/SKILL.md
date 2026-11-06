---
name: docs-review
description: Review a pull request for documentation drift and documentation-rule violations, and post findings as PR comments. Proposes only; changes nothing.
allowed-tools: Read, Grep, Glob, mcp__github_inline_comment__create_inline_comment
---

# Documentation review of a pull request

Arguments: `<pull request number> <path to the diff file>`.

You review. You never edit files, change a status, or approve anything. Every finding is a
proposal for the repository owner, who alone decides.

In a pull request run, `.claude/`, `CLAUDE.md`, and `.mcp.json` in the checkout are the base
branch's versions: the action restores them from the base for safety. The pull request's
versions are in the diff and under `.claude-pr/`. Read a changed file of those paths there, and
never run anything from them.

## Procedure

1. Read `AGENTS.md`, then sections 2, 3, 5, 6, 7 and 9 of `docs/documentation-rules.md`, and the
   map `docs/README.md`. They define document kinds, statuses, the lifecycle, file ownership, the
   review checklist, and the owner document for each kind of fact. Do not restate them; apply them.
2. Read the diff file. Classify each changed file:
   - documentation: Markdown under `docs/` or at the root;
   - rules and structure: `AGENTS.md`, `CLAUDE.md`, `docs/README.md`,
     `docs/documentation-rules.md`, `docs/contributing.md`, checks, hooks, workflows, skills;
   - contracts: anything under `contracts/`;
   - code: everything else.
3. Documentation changes: go through the semantic review checklist in section 7, item by item.
   Report a statement whose status does not match its evidence, an invented requirement or
   decision, duplicated content, a missing map or link update, and an edit to an ADR that exists on
   `main` beyond its status line (the `decisions` workflow checks the same
   mechanically, so report only what it cannot see). Report also a new ADR for a decision that
   does not meet the criteria of section 5 (it belongs in its owner document), a new ADR that
   lists rules or design details instead of linking the owner document; a convention or recipe
   that a changed skill or tool-specific rule file, wherever it is (such as `.cursor/rules/`,
   `.claude/rules/`), holds instead of linking `docs/conventions/` or `docs/recipes/`; and a
   convention that names neither the check that enforces it nor `none`
   (`docs/documentation-rules.md`, section 2); the path class of such a file follows section 8.
   Whether a new `Decided by the owner` marker matches the owner's words is not yours to judge: the readiness
   check verifies the listing, and the owner's merge decides.
4. Code and contract changes, the drift check: for each change that alters behaviour, an
   interface, a schema, a command, a configuration or an operational procedure, find the owner
   document through the map in `docs/README.md` and by searching `docs/` for the affected names.
   If the owner document is not updated in the same pull request, report it with the file and
   the missing update. A contract change without the matching documentation and tests is a
   finding. A documentation claim of implemented behaviour without a test in the pull request is
   a finding. Internal refactoring that leaves behaviour, contracts and operations unchanged is
   not a finding.
5. Rules and structure changes are class approval (`docs/documentation-rules.md`, section 8): the
   owner approves each edit before it is made, and the description names the instruction under
   "Notes for the owner". Review their content like any other documentation change.
6. Post one inline comment per finding on the relevant line with the inline comment tool. Start
   each comment with its class, `blocker` or `suggestion` as `docs/contributing.md`, section 6,
   defines them, state the finding in one or two sentences, and name the rule or owner document
   it rests on. When there are no findings, post nothing and say so in the log. This is the only
   pass: do not hold back a finding for a later one.
7. Do not report style preferences, do not repeat markdownlint or link check output, do not invent
   requirements, and do not propose content for the owner document beyond naming what is missing.
