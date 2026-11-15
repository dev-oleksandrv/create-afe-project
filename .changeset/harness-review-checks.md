---
"create-afe-project": minor
---

Checks and hooks from the harness review of 2026-11. No check of an existing project starts
failing; what a project notices:

- Review classes (`scripts/lib/classes.sh`): `AGENTS.md`, `CLAUDE.md`, the files under
  `.claude/skills/`, `.claude/rules/`, `.claude/agents/`, and `.claude/commands/`, and
  `.claude/settings.json` are now class normal, so a change of them gets one reviewer; other
  Markdown stays low. The template-update exemption (review none) now needs a `_version` of
  `.afe-answers.json` that differs from the base's, no path of class high or gate, no seeded file
  in the change (`README.md`, `CLAUDE.md`, `.gitignore`, `.claude/path-classes`,
  `.claude/harness.conf`, `.claude/settings.project.json`), and the project block of `AGENTS.md`
  as on the base. Before,
  any edit of the answers file, whitespace included, skipped the review and overrode high and
  gate. More pull requests, template updates among them, now get a review.
- Stop hook (`.claude/hooks/stop-dispatch.sh`, `scripts/lib/stamp.sh`): the docs stamp also
  covers the names of the other paths, a deleted or renamed path of the base runs
  `scripts/check-docs.sh` on every document, and only that full check stores the docs stamp. Before,
  a green Stop stayed green after a link target was deleted.
- `scripts/check.sh --if-changed` also compares the base of the change, so a moved base re-runs
  the checks on the same tree.
- Lock (new `scripts/lib/lock.sh`, opt-in): `CHECK_LOCK` names a lock that every checkout of the
  user on the machine with the same name shares; `scripts/check-project.sh` and
  `scripts/env.sh fast|e2e` run under it and wait up to `CHECK_LOCK_WAIT` seconds (900), and a
  sub-agent's Stop skips `CHECK_FAST` while another process holds it. It addresses test timeouts
  when parallel sessions ran Docker-backed checks at once, in six pull requests of one generated
  project; added on the owner's decision of 2026-11-15. `.claude/harness.conf` is seeded: an
  existing project that wants the lock adds `CHECK_LOCK=<name>` and `CHECK_LOCK_WAIT=900` by
  hand.
- Guard hook (`.claude/hooks/guard.sh`): the command is read as words, so a push named inside
  quoted data, such as a commit message, is no longer denied; the command string of `bash -c`,
  `sh -c`, `zsh -c`, and `eval`, a command substitution in double quotes, and a subshell are
  scanned, and every form the guard denied before is still denied.
- `scripts/check-links.mjs` accepts `path:line-line` in a backticked code path that exists.
- The `DIFF_WARN_LINES` warning of `scripts/check-decisions.sh --ready` leaves out lock files and
  test files (`TEST_GLOBS`, or the common patterns while it is empty); it fired on 51 of 95 pull
  requests of one project and was ignored; changed on the owner's decision of 2026-11-15.
- `scripts/fail-without-change.sh` prints the last 20 lines of the base run of each test that
  fails there, so the pull request can quote the reason.
- New `scripts/check-review-evidence.mjs [--head <sha>] [--base <sha>] [--level one|two] <file>`:
  validates the review evidence that an outside review engine hands to `create-pr`, as a chain of
  clean reviews from the base to the head with no open blocker; its header holds the file format.
  Added on the owner's decision of 2026-11-15.

Evidence: the review findings on instruction Markdown as class low, the update exemption, and the
green stamps (one of them a reproduced green Stop after a deleted link target), and the history
of the generated project for the lock and the size warning.
