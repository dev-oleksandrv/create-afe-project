---
name: afe-init
description: Set up the project itself on top of the template - interview the owner about what to build and with which stack, record the answers in the requirements, one decision record, and the project block of AGENTS.md, scaffold the code with the stack's own generator, and wire the verification gates (format, lint, types, tests, end-to-end, a smoke test per deployable part, the check after every edit) into the template's slots, proving that each gate fails when it should; all in one branch and one pull request. Run once by the owner, in a new repository or one adopted by the template.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(git status:*), Bash(git switch:*), Bash(git diff:*), Bash(git log:*), Bash(scripts/check.sh:*), Bash(scripts/env.sh:*), Bash(scripts/gen-decisions-index.sh:*), Bash(scripts/gen-settings.sh:*)
---

# Initialize the project

Arguments: none, or a sentence about what to build.

The owner started this skill: the answers given in it are the owner's instructions, so what the
owner confirms is recorded as decided, and nothing else is. Read `AGENTS.md` first; this skill
applies it.

## 1. Look before asking

- `git status --porcelain` must be empty; otherwise stop and report.
- Find what exists: manifests and lockfiles (`package.json`, `pyproject.toml`, `go.mod`,
  `Cargo.toml`, `pom.xml`, `build.gradle*`, `*.csproj`, `Gemfile`, `composer.json`, `mix.exs`),
  source folders, test folders, CI files, `.claude/harness.conf`, `scripts/checks.d/`, and the
  documents under `docs/`. With code present, propose the answers below from what exists and ask
  the owner to confirm or correct them, instead of asking from scratch.

## 2. Interview

Ask one topic at a time, with a structured question tool when the client has one. For each
choice, offer a recommendation with a one-line reason, marked as a proposal; the owner chooses.
An answer the owner does not give is an open question, never a default you invent.

1. Product: what it is, for whom, and the first three to five things it must do. Each becomes a
   requirement.
2. Shape: web app, API, CLI, library, mobile or desktop app, data or ML pipeline, or another;
   where it runs and where it deploys (or "not decided").
3. Stack: language and version, framework, package manager, storage, test runner, formatter,
   linter, and type checker, and the end-to-end tool (browser automation, API tests, CLI golden
   tests, an emulator) when the product needs one.
4. Stage, per the AFE guide: starting (prototype), growing (real users), or at scale. It sets the
   depth: starting gets format, lint, types, and unit tests; growing adds end-to-end tests,
   coverage of the risky paths, and the check after every edit; at scale adds coverage
   thresholds and contracts. Ask before going deeper than the stage.
5. Operation: how it runs locally, the services it needs, and its configuration (names only,
   never values).
6. Sandbox: whether to turn on the Claude Code sandbox for the project (default off). It
   confines the shell commands Claude runs, and what they start, to writes in the working and
   temporary directories and to network hosts on an allowlist, on macOS, Linux, and WSL2. It does
   not cover the Read, Edit, Write, and WebFetch tools (the permission rules do), the hooks,
   which run the checks with full access, MCP servers, or the commands in `excludedCommands`,
   which also run with full access; Docker does not run inside it. A sandboxed command may not
   write `.claude/` settings, skills, or hooks, so `scripts/gen-settings.sh` and a template
   update run outside it. Where the platform cannot run it, commands run unsandboxed.

## 3. Confirm

Show one table: every decision, its value, and the files that will change. Write nothing until
the owner confirms; change what the owner corrects.

## 4. Record, scaffold, wire

One branch, `chore/project-setup` (`git switch -c chore/project-setup`), and one pull request,
opened with the `create-pr` skill. It holds:

- `docs/requirements.md`, under the heading `# Requirements` and without front matter: one line
  per requirement, `REQ-001: <statement>` onward, each followed by its acceptance criteria
  lines, `AC-01: Given <context>, when <action>, then <outcome>`, numbered across the file.
- One ADR for the stack from `docs/decisions/adr-template.md`, `status: accepted` on the owner's
  confirmation, the owner as decision-maker, the options considered with the owner's reasons;
  regenerate the index with `scripts/gen-decisions-index.sh > docs/decisions/README.md`.
- The project block of `AGENTS.md` (at most 10 lines): what the project is, its stack, its
  commands.
- The scaffold:
  - Run the stack's own generator or init command (`npm create`, `cargo new`, `uv init`,
    `dotnet new`, and the like); show the exact command first. Never write a framework skeleton
    from memory when a generator exists.
  - Pin the toolchain (`engines` and `.nvmrc`, `.python-version`, `rust-toolchain.toml`,
    `.tool-versions`, and the like); commit the lockfile; add `.env.example` with every setting
    and a safe non-secret default. The settings deny `Read(**/.env.*)` except what the negation
    `Read(!.env.example)` after it carves out, so that file is open and every other `.env.*`
    stays denied; never take either rule out.
  - Every dependency exists on its registry and is maintained; list each in the pull request.
- The checks: `scripts/checks.d/20-lint.sh`, the formatter check, linter, and type checker,
  strict, errors fail; `scripts/checks.d/30-test.sh`, the unit tests, offline and
  deterministic; and `scripts/checks.d/40-e2e.sh` for end-to-end tests when the stage needs
  them. Each check installs what it needs beyond Git, bash, and Node.js, and prints nothing on
  success. At every stage, each deployable part (an app, a server, a CLI) also gets one
  automated smoke test in `scripts/checks.d/` that builds or starts it and checks one observable
  result, such as a page that renders, a health endpoint that answers, or `--help` that prints.
- `.claude/harness.conf`: `SETUP`, `CHECK_FAST` (the changed files' lint and related tests,
  under about 30 seconds), `E2E` (set, or the pull request says why not), `RESET`, `CHECK_EDIT`
  and `CHECK_EDIT_GLOBS` (formatter check and linter on one file, a few seconds), `TEST_GLOBS`,
  and `FWC_TEST` when the fail-without-change module is on.
- On the owner's yes to the sandbox: `.claude/settings.project.json` gets
  `"sandbox": {"enabled": true, "network": {"allowedDomains": [...]}}` with the registries and
  hosts the setup and the checks need, and `"excludedCommands"` only for the Docker commands the
  checks run, each named in the pull request because it runs with full access; then run
  `scripts/gen-settings.sh`. Each check that needs Docker or the network is run once in a session
  with the sandbox on, and the pull request says what failed and what was added for it.
- `.claude/path-classes`: a `gate` line for each configuration file of the chosen stack: the
  manifest, the lock file, the toolchain file, and the configuration of the linter, formatter,
  type checker, test runner, and coverage. A gate does not move to get a pass.
- A first test that carries `REQ-001`, written first and seen to fail, then made to pass.

## 5. Prove every gate

A gate that never failed is not wired. For each of format, lint, types, unit tests, end-to-end
tests, each smoke test, and `CHECK_EDIT`: introduce one deliberate violation in a scratch change, run the gate,
see it fail with the expected message, and revert. The pull request lists each gate with the
command and the failing line it printed. Then `scripts/check.sh` passes.

## 6. Report

The decisions recorded and where, the pull request, every gate with its proof, the commands of
`scripts/env.sh`, the assumptions, and the open questions for the owner.
