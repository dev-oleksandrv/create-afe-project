---
"create-afe-project": minor
---

`.claude/hooks/stop-check-fast.sh`, a Stop hook: Claude Code may not finish a turn while the
project's fast check fails. It runs `scripts/env.sh fast` (`CHECK_FAST` of
`.claude/harness.conf`) when a file other than Markdown differs from the base, committed or not,
and blocks through the Ralph cap; it skips when `CHECK_FAST` is empty or the default
`scripts/check-docs.sh`, and during merge conflicts. `.claude/settings.template.json` registers
it, `.template/owned.txt` lists it, and `docs/documentation-rules.md`, section 7, names it. Added
on the owner's instruction of 2026-11-05, ported from agent-docs-template 0.7.0; no observed
failure. The seeded `.claude/harness.conf` names the hook in its comment: an existing project may
copy those two lines by hand.
