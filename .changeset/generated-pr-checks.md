---
"create-afe-project": patch
---

The `decisions`, `docs-review`, and `code-review` workflows treat a pull request that a workflow
opened with `GITHUB_TOKEN` (author `github-actions[bot]`), such as a generated release pull
request, as generated: readiness checks only its decision records, not the description
sections, and the AI reviews skip it. Before, readiness failed on the generated description and
claude-code-action failed with "Workflow initiated by non-human actor". Observed on this
repository's Version PR #16.
