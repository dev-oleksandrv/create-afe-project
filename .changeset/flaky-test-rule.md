---
"create-afe-project": minor
---

`docs/testing-rules.md`, section 2: a flaky test is fixed, never retried or rerun until green;
skipping it is a blocker of section 4 unless the owner, asked, decides otherwise. The bullet on
failure paths is reworded to stay within the line budget, without a change in meaning. Added on
the owner's instruction of 2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
