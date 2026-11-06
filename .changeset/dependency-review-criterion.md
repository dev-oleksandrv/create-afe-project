---
"create-afe-project": minor
---

`docs/contributing.md`, section 6: the review criterion "Dependencies": a new dependency exists in
its registry under the name used, is maintained, has a license the project allows (an open
question while no document says which), does no job an existing one already does, and is pinned
exactly, through the lock file where the stack has one. The `review-code` skill checks duplication
and pinning in the files, and the rest when it can reach the registry; otherwise it leaves them to
the owner's review of the gate file. To stay within the line budget, the blocker bullet of the
same section is rewrapped with two rewordings of the same meaning: "zero findings is valid" for
"zero findings is a valid result", and "fails an item of its Acceptance section" for "fails a
criterion of its Acceptance section", as section 3 already calls them items. Added on the owner's instruction of
2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
