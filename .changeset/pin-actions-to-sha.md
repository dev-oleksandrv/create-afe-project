---
"create-afe-project": patch
---

Security: every action in the workflows is pinned to a full 40-character commit SHA with its
release as a comment, such as `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`,
instead of a tag. A tag can move, and the `code-review` and `docs-review` jobs hold
`CLAUDE_CODE_OAUTH_TOKEN`. The versions are unchanged: `actions/checkout` v7.0.1,
`actions/setup-node` v7.1.0, `DavidAnson/markdownlint-cli2-action` v25.0.0, and
`anthropics/claude-code-action` v1.0.268. A project sees these workflows change on the update:
`.github/workflows/docs.yml` and `.github/workflows/decisions.yml`, and with their modules
`.github/workflows/secret-scan.yml`, `.github/workflows/docs-review.yml`,
`.github/workflows/code-review.yml`, and `.github/workflows/fail-without-change.yml`. The update
replaces them; nothing is to do by hand. From the owner's instruction of 2026-11-07, before the 2.1.0 release.
