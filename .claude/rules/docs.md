---
paths:
  - "docs/**"
  - "*.md"
---

# Documentation rules

- Write every document in English. One fact has one place; link to it, never copy it.
- Change a document when a change makes a statement in it false, once, at the end of the
  change. No placeholders, no status or verification front matter.
- Reference code by a path that exists: a Markdown link or a backticked path. The link check
  (`scripts/check-links.mjs`) fails on a path that does not exist, in `AGENTS.md` and under
  `docs/`; records under `docs/decisions/` are exempt from the backticked-path check, not from
  the link check.
- Write a decision record only for a choice that is costly to reverse and had a real
  alternative: language, runtime, framework; storage and persistent formats; public contracts;
  the security model; an external service. Copy `docs/decisions/adr-template.md` and take the
  next number. It is accepted when written; a later record that replaces it names it under
  `supersedes`.
- Plans, research notes, logs, and agent reports never enter `docs/`.
