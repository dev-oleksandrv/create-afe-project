---
"create-afe-project": minor
---

The seeded `.claude/path-classes` lists the gate files of any stack as their own block:
Dependabot, Renovate, pre-commit, Make (with `*.mk` and the Makefiles of subdirectories), just,
Task (with `Taskfile.dist.yml`), `.tool-versions`, and mise (with its environment files and its
configuration under `.config/`, `mise/`, and `.mise/`), so a change to
dependency updates, pre-commit hooks, task runners, or tool versions is named under "Gate files"
and reviewed by the owner. On the owner's instruction of 2026-11-05, ported from
agent-docs-template 0.7.0; no observed failure. An update never changes a seeded file: an existing
project copies the block "Gates of any stack" into its `.claude/path-classes` by hand.
