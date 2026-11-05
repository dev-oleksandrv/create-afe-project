---
"create-afe-project": minor
---

`docs/testing-rules.md`, section 2: a flaky test is fixed, never retried or rerun until green;
skipping it is a blocker of section 4 unless the owner, asked, decides otherwise. To stay within
the line budget, the bullet on failure paths is rewrapped into two lines, with "every invalid
contract example is rejected where input is validated" for "every invalid example of a contract is
rejected where the input is validated", the same meaning. Added on
the owner's instruction of 2026-11-05, ported from agent-docs-template 0.7.0; no observed failure.
