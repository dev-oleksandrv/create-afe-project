---
"create-afe-project": patch
---

Hooks and the `decisions` workflow: stale references and two masked failures.

- `.claude/hooks/session-start.sh` and the Stop hooks `stop-check-fast.sh`, `stop-check-docs.sh`,
  `stop-check-decisions.sh`, and `stop-check-template.sh` no longer tie a merge conflict to a
  template update or point to `docs/contributing.md`, section 5, which since 1.0.0 is the npm
  update and produces no conflict markers; their message now says that `git status` lists the
  conflicts.
- `.claude/hooks/post-edit-check.sh` runs `CHECK_EDIT` with stdin from `/dev/null`, as upstream
  does, instead of the hook's input pipe, which the hook has already read to its end; a command
  that behaves differently when stdin is a pipe no longer sees one.
- `.github/workflows/decisions.yml`: the header says that the ruleset of
  `scripts/protect-branch.sh` requires `integrity` once it is set, and that `readiness` is never
  required. The readiness step runs with `shell: bash`, so pipefail applies and a failing
  `--classes` call for a pull request that a workflow opened fails the step instead of being
  hidden by the pipe into `awk`.

PATCH (`docs/maintaining.md`, section 4: wording and script bugs). All the files are
template-owned: `update` replaces them, and an existing project does nothing by hand. From the
review of 2.0.0, on the owner's instruction of 2026-11-06.
