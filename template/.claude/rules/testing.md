---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/*_test.*"
  - "**/test_*.py"
  - "**/test/**"
  - "**/tests/**"
  - "**/__tests__/**"
---

# Testing rules

- A test protects a behaviour someone asked for or a defect that was fixed. Write it before the
  code and see it fail for the expected reason; a test that passes without the change tests
  nothing.
- Assert what a user of the code can observe: the returned value, the resulting state, the
  output. That a mock was called, or that nothing threw, is not enough on its own.
- Expected values are literals or fixtures, never computed with the logic under test.
- Fakes stand in for the boundaries (external services, storage, the clock, randomness), never
  for code inside the unit.
- One behaviour has one test, or one table of inputs. Remove a test that catches nothing the
  others miss. Count and coverage are not goals.
- No test for what the type checker or a schema already proves, and none for a case that cannot
  happen.
- Tests are deterministic: no sleeps, no real clock or network, no dependence on order. A flaky
  test is fixed, never retried.
- Never skip, focus, weaken, or delete a test to get a pass. When one seems wrong, say so.
