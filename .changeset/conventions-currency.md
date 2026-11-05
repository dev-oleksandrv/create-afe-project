---
"create-afe-project": minor
---

`docs/documentation-rules.md`, sections 2 to 4 and 6: conventions and recipes, like
architecture and operations, carry `verified-against` (`none` while no code exists) and move from
`draft` to `current`; a convention names the lint rule or check that enforces it, or `none` when
only the review does; a tool-specific rule file or skill links to them and never holds its own
copy. The `docs-review` skill reports a convention or recipe copied into a tool-specific rule
file (such as `.cursor/rules/`, `.claude/rules/`) or a skill, and `review-code` applies the
conventions of the areas a diff changes. No check reads the field: an existing conventions or
recipes document gets it at its next review. Added on the owner's instruction of 2026-11-05,
ported from agent-docs-template 0.7.0; no observed failure.
