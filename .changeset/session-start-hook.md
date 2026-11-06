---
"create-afe-project": minor
---

`.claude/hooks/session-start.sh`, a SessionStart hook: a new, resumed, or compacted session
starts from at most ten lines of local facts: the branch, its base and the commits ahead,
uncommitted and untracked files, merge conflicts, and each plan in `docs/plans/` with its
`review-by`, flagged when it is past. No network; it always exits 0.
`.claude/settings.template.json` registers it, `.template/owned.txt` lists it, and
`docs/documentation-rules.md`, section 7, names it under "Currency". Added on the owner's
instruction of 2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
