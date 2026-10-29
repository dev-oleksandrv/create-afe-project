# Changelog

All notable changes to the template are listed here, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[`docs/maintaining.md`](docs/maintaining.md), section 4.

## [Unreleased]

## [0.1.0] - 2026-10-29

### Added

- Agent rules (`AGENTS.md` with one project block, `CLAUDE.md`), documentation rules with file
  ownership (`docs/documentation-rules.md`), contribution and template update rules
  (`docs/contributing.md`), and the seeded documentation map (`docs/README.md`).
- Short decision records: `docs/decisions/adr-template.md` and the generated index
  `docs/decisions/README.md` (`scripts/gen-decisions-index.sh`).
- Checks behind one entry point, `scripts/check.sh`: documentation (markdownlint-cli2, lychee),
  decision records (integrity, next number, index, merge readiness), template integrity
  (`.template/owned.sha256`), and project checks from `scripts/checks.d/`.
- Claude Code hooks (protect, Stop checks, project Stop hooks from `.claude/hooks/project/stop/`)
  and skills (`create-pr`, `update-template`, and `docs-review` as the `docs_review` module).
- CI workflows `docs` (with Node.js set up), `decisions`, and `docs-review`, with the runner chosen
  by a question and overridable by the repository variable `CI_RUNS_ON`.
