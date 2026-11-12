---
paths:
  - "docs/**"
  - "*.md"
---

# Documentation rules

- Write every document in English.
- One fact has one place; link to it, never copy it.
- Create a document when it has real content. No placeholders, and no status or verification
  front matter.
- Reference code by a path that exists: a Markdown link, or a backticked path. The link check
  (`scripts/check-links.mjs`) fails on a path that does not exist, in `AGENTS.md` and under
  `docs/`.
- Write an ADR only for a decision that is costly to reverse and had a real alternative:
  language, runtime, framework; storage and persistent formats; public protocols and contracts;
  security, isolation, authentication model; external service or infrastructure. Copy
  `docs/decisions/adr-template.md`, take the next number, and regenerate the index with
  `scripts/gen-decisions-index.sh > docs/decisions/README.md`.
- Research notes, logs, transcripts, and agent reports never enter `docs/`.
