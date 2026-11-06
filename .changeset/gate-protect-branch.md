---
"create-afe-project": minor
---

The protect hook (`.claude/hooks/protect-docs.sh`) treats a change of repository settings as an
irreversible action and asks the owner first: `scripts/protect-branch.sh` without `--dry-run`, by
any path or through `bash`, `sh`, `zsh`, or `source`, and `gh api` with the method PATCH, PUT, or
POST (`-X`, `--method`, or POST implied by `-f`, `-F`, `--field`, `--raw-field`, or `--input`) on
`repos/OWNER/REPO` itself, its `rulesets`, or a `branches/BRANCH/protection`. Before, the header
of `scripts/protect-branch.sh` said an agent runs it only on the owner's explicit instruction, but
nothing enforced it. Reads, `--dry-run`, and the comment replies and reads of the `create-pr`
skill still pass without a prompt. An existing project gets the hook with the template update and
does nothing by hand; a headless run (CI) that ran `scripts/protect-branch.sh` without
`--dry-run` through Claude Code is now denied. From the 2.0.0 review, on the owner's instruction
of 2026-11-06.
