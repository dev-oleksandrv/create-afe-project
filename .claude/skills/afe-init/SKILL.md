---
name: afe-init
description: Set up the project itself on top of the template - interview the owner about what to build and with which stack, scaffold the code with the stack's own generator, wire the checks (format, lint, types, tests, the check after every edit) into the template's slots and prove that each one fails when it should, and write down how to run the product and see a change. One branch, one pull request. Run once by the owner, in a new repository or one adopted by the template.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(git status:*), Bash(git switch:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git push -u origin chore/project-setup), Bash(gh pr create:*), Bash(scripts/check.sh:*), Bash(scripts/env.sh:*), Bash(scripts/gen-settings.sh:*)
---

# Initialize the project

Arguments: none, or a sentence about what to build.

The owner started this skill: what the owner answers or confirms here is decided, and nothing
else is. Read `AGENTS.md` first.

## 1. Look before asking

- `git status --porcelain` must be empty; otherwise stop and report.
- Find what exists: manifests and lockfiles, source and test folders, CI files,
  `.claude/harness.conf`, `scripts/checks.d/`, and the documents under `docs/`. With code
  present, propose the answers below from what exists and ask the owner to confirm or correct
  them, instead of asking from scratch.

## 2. Interview

Ask with a structured question tool when the client has one, independent questions together.
For each choice offer a recommendation with a one-line reason; the owner chooses.

1. Product: what it is, for whom, and the first three to five things it must do.
2. Shape: web app, API, CLI, library, mobile or desktop app, pipeline, or another; where it
   runs and where it deploys (or "not decided").
3. Stack: language and version, framework, package manager, storage, test runner, formatter,
   linter, type checker, and the end-to-end tool when the product needs one.
4. Operation: how it runs locally, the services it needs, its configuration (names only, never
   values), and how one looks at a change: the command that starts it, and the URL, endpoint,
   or command that shows it working.
5. Sandbox: whether Claude Code's sandbox is on for this project (`README.md`, "Sandbox").

## 3. Confirm

Show one table: every decision, its value, and the files that will change. Write nothing until
the owner confirms.

## 4. Scaffold and wire

One branch, `chore/project-setup`, and one pull request. It holds:

- The scaffold. Run the stack's own generator or init command and show the exact command
  first; never write a framework skeleton from memory when a generator exists. Pin the
  toolchain, commit the lockfile, and add `.env.example` with every setting and a safe
  non-secret default.
- `docs/requirements.md`: one line per thing the product must do, in the owner's words.
- One decision record for the stack, from `docs/decisions/adr-template.md`, decided by the
  owner.
- The project block of `AGENTS.md` (at most 20 lines): what the project is, its stack, and
  under "Run and see" the commands that start the product and show a change working, one per
  deployable part.
- The checks: `scripts/checks.d/20-lint.sh` (formatter check, linter, type checker; errors
  fail), `scripts/checks.d/30-test.sh` (unit tests, offline and deterministic), and
  `scripts/checks.d/40-e2e.sh` when the product needs end-to-end tests. Each deployable part
  gets one smoke test that starts it and sees it answer. A check prints nothing on success.
- `.claude/harness.conf`: `SETUP`, `CHECK_FAST` (the changed files' lint and related tests,
  well under a minute), `E2E`, `RESET`, `CHECK_EDIT` and `CHECK_EDIT_GLOBS` (formatter check
  and linter on one file, a few seconds).
- `.claude/risky-paths`: the paths of this product where a mistake costs most, added to the
  defaults.
- On the owner's yes to the sandbox: `.claude/settings.project.json` gets
  `"sandbox": {"enabled": true, "network": {"allowedDomains": [...]}}` with the registries and
  hosts the setup and the checks need, and `"excludedCommands"` only for the Docker commands
  the checks run, each named in the pull request; then run `scripts/gen-settings.sh`.
- A first test of the first requirement, written first and seen to fail, then made to pass.

## 5. Prove every check

A check that never failed is not wired. For each of format, lint, types, unit tests,
end-to-end tests, each smoke test, and `CHECK_EDIT`: make one deliberate violation, run the
check, see it fail with the expected message, and revert. Then `scripts/check.sh` passes, and
the product runs the way "Run and see" says.

## 6. Deliver

Commit, push the branch, and open the pull request (`gh pr create`). Its description: the
decisions and where they are recorded, each check with the command and the failing line that
proved it, how to run the product, and what is still open for the owner.
