---
"create-afe-project": minor
---

`docs/documentation-rules.md`, sections 7 and 9, now name the check after every edit: the
"Project checks" row says that `CHECK_EDIT` runs on each file an Edit, Write, or MultiEdit call
changes and `CHECK_EDIT_GLOBS` matches, and that a file changed by a shell command waits for
`scripts/check.sh`. The harness settings of section 9 list the environment and test commands,
`CHECK_EDIT`, and `CHECK_EDIT_GLOBS`. The header of `.claude/hooks/post-edit-check.sh` now cites `docs/documentation-rules.md`,
section 7, instead of `docs/testing-rules.md`, section 4. The `docs-review` skill reads section 4
(Currency) and reports two findings: a document of a kind that section 4 requires to carry
`status`, `date`, and `verified-against` but lacks one of them, and a changed one that keeps a
stale `verified-against`.

The seeded map `docs/README.md` changes for new projects only. Its README row now also names "the
repository settings the owner sets once". An existing project copies that row by hand. These
fixes come from the 2.0.0 review, on the owner's instruction of 2026-11-06. Nothing went wrong
because of these gaps.
