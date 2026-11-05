---
"create-afe-project": minor
---

`scripts/protect-branch.sh` applies the repository settings the rules assume, before the
ruleset: merge commits only, without squash and rebase merging, and "Automatically delete head
branches", on every plan; secret scanning with push protection, where a refusal (a private
repository without GitHub Advanced Security) is reported and the run goes on. The ruleset allows
only merge commits, and `--require-base` also requires the `base` job of the
`fail-without-change` workflow, once it has passed in CI on a pull request that changes a test.
`--dry-run` prints the settings and the ruleset as one JSON object. `docs/contributing.md`,
sections 1 and 3, and the `fail-without-change` workflow name the script; the message after create
names the settings in place of the separate step for secret scanning. On the owner's instruction
of 2026-11-05, ported from agent-docs-template 0.7.0; no observed failure. `README.md` is seeded:
an existing project copies its section "Protected main branch" by hand, and runs
`scripts/protect-branch.sh` again to apply the settings.
