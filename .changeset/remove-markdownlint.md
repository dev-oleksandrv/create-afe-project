---
"create-afe-project": minor
---

The Markdown lint is gone: `scripts/check-docs.sh` runs only the link check with its check of
backticked code paths, and needs Node.js but no longer `npx`. `update` removes the template-owned
`.markdownlint-cli2.jsonc`. A failing documentation check in the Stop dispatcher is reported as its
first 10 lines, how many lines remain, and the command for the full output.
