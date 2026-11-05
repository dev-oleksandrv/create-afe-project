---
"create-afe-project": minor
---

`docs/contributing.md`, section 6: the review criterion "Dependencies": a new dependency exists in
its registry under the name used, is maintained, has a license the project allows (an open
question while no document says which), does no job an existing one already does, and is pinned
exactly, through the lock file where the stack has one. The `review-code` skill checks duplication
and pinning in the files, and the rest when it can reach the registry; otherwise it leaves them to
the owner's review of the gate file. The blocker bullet of the same section is rewrapped to stay
within the line budget, without a change in meaning. Added on the owner's instruction of
2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
