---
"create-afe-project": minor
---

`docs/testing-rules.md`, section 2: a flaky test is fixed, never retried or rerun until green;
skipping it is a blocker of section 4 unless the owner, asked, decides otherwise. To stay within
the line budget, the bullet on failure paths is reworded with the same meaning: each distinct
outcome or error a unit can return has a test that produces it; each invalid contract example is
rejected at validation. Added on
the owner's instruction of 2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
