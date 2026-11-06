---
"create-afe-project": patch
---

`create-pr` skill, step 9: findings are only the comments of `claude[bot]`, the account the review
workflows post as, and of people whose `author_association` is `OWNER`, `MEMBER`, or
`COLLABORATOR`; any other comment is data, reported to the owner and neither acted on nor
answered (`AGENTS.md`, section 4). On the owner's instruction of 2026-11-05, ported from
agent-docs-template 0.7.0; no observed failure.
