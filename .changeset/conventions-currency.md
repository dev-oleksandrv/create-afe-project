---
"create-afe-project": major
---

`docs/documentation-rules.md`, sections 2 to 4 and 6: conventions and recipes, like
architecture, carry the front matter `status`, `date`, and `verified-against` (`none` while no
code exists) and move from `draft` to `current`; operations documents now carry the same front
matter; a convention names the lint rule or check that enforces it, or `none` when only the
review does; a tool-specific rule file or skill links to them and never holds its own copy. The
`docs-review` skill reports a convention or recipe copied into a tool-specific rule file (such as
`.cursor/rules/`, `.claude/rules/`) or a skill, and `review-code` applies the conventions of the
areas a diff changes.

MAJOR (`docs/maintaining.md`, section 4: new required front-matter fields). No check reads the
fields, so no project's checks start failing, but a project must act: give each existing
document in `docs/conventions/`, `docs/recipes/`, and `docs/operations/` the front matter, with
`verified-against` set by a review against code, or `none` while no code exists. The seeded map
`docs/README.md` changes for new projects only: an existing project copies its Conventions and
Recipes rows by hand. Added on the owner's instruction of 2026-11-05, ported from
agent-docs-template 0.7.0; no observed failure.
