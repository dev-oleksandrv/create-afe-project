---
"create-afe-project": patch
---

`docs-review` and `code-review` workflows: `anthropics/claude-code-action` is pinned to
`v1.0.268`, the release the floating `v1` pointed to on 2026-11-05, like every other action, so a
new release of the action changes nothing until a pull request moves the pin. A project with a
review module sees its workflow change on the update. On the owner's instruction of 2026-11-05,
ported from agent-docs-template 0.7.0.
