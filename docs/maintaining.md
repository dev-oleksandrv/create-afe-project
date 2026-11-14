# Maintaining the template

How the template is changed, tested, versioned, and released. Questions, seeded files, tasks,
and migrations are in [`src/config.js`](../src/config.js); the command line that creates and
updates projects is [`bin/create-afe-project.js`](../bin/create-afe-project.js) with
[`src/`](../src/); the rules a generated project follows are in [`template/`](../template/).

## 1. Model

- `template/` is the product. Every file in it is one of four kinds. Template-owned files are
  listed in [`template/.template/owned.txt.jinja`](../template/.template/owned.txt.jinja): an
  update replaces them, and `scripts/check-template.sh` fails on a local edit. Seeded files are
  listed as `SEEDED` in `src/config.js`: created once, then owned by the project; an update
  changes one only through a `MIGRATIONS` entry. Generated files are rebuilt after every create
  and update: the answers file by the command line, the settings, the ownership manifest, and
  the decision index by the `TASKS` of `src/config.js`. Every other file belongs to the project.
  Files render with Nunjucks, which reads the Jinja syntax: a `.jinja` file is rendered and loses
  the suffix, a path segment that renders empty drops the file, and `_gitignore` becomes
  `.gitignore`, because npm never publishes a `.gitignore`.
- This repository's own `.afe-answers.json` records the version of `package.json`: its
  template-owned files come from the working tree of `template/` through `scripts/sync-self.sh`,
  which runs the `update` command of this working tree, not from a release.
- A project extends the template only at its extension points: `scripts/checks.d/`,
  `.claude/hooks/project/stop/*.sh`, `.claude/path-classes`, `.claude/harness.conf`,
  `.claude/settings.project.json`, the project block of `AGENTS.md`, and its own documents. A
  need that the extension points do not cover is a change of the template, not a local edit.
- Optional parts are modules behind a question of `src/config.js` (today: `code_review`,
  `secret_scan`, `acceptance_check`, and `fail_without_change`). A module's files use a
  conditional file name, and the documents mention the module only inside the same condition.
- What a generated project runs. The checks: `scripts/check.sh` runs `scripts/check-project.sh`
  (the project's `scripts/checks.d/`), `scripts/check-docs.sh` (the links and the code paths of
  `scripts/check-links.mjs`, judged by the files git knows), `scripts/check-decisions.sh`, and
  `scripts/check-template.sh`, with a green stamp (`scripts/lib/stamp.sh`) for `--if-changed`. The stamp has two kinds, `docs` (Markdown) and
  `code` (every other path), each over the content of its files in a temporary index, not over
  `HEAD` or the real index, so neither `git add` nor `git commit` of the same content changes it;
  the blobs it hashes go to a temporary object directory, so it adds nothing to `.git`;
  `--if-changed` skips only when the `full` stamps of both kinds match.
  The hooks of `.claude/hooks/`: `guard.sh` asks before an edit of `AGENTS.md`, a known token
  format, and the irreversible commands it names, and denies a push to the default branch;
  `stop-dispatch.sh` checks what changed at each Stop and SubagentStop, running the checks of a
  kind only when its stamp does not match, up to the Ralph cap, counted per session, agent, and
  worktree; it tells the user at the cap and then lets the same key stop on the same tree without
  running anything until the tree changes. Its failure message gives each failing part the last
  40 lines of its output, except `scripts/check-docs.sh`: the first 10 lines, how many lines
  remain, and the command for the full output (a missing tool: the first 10 lines). A sub-agent
  that stops in the main session's tree (the root of `CLAUDE_PROJECT_DIR`) runs nothing: the main
  agent's Stop checks it. `post-edit-check.sh`
  runs `CHECK_EDIT`; `session-start.sh` prints the local state. The last three resolve the
  generated project, the nearest git repository with `.template/owned.txt`, from the input's
  `cwd` (`scripts/lib/root.sh`), so they work in any git worktree and for sub-agents and pass
  over a nested repository without the harness; the guard hook judges a path in any worktree
  too. The skills: `create-pr` (with the `review` skill and its rubric), `afe-init`,
  `update-template`, and, with its module, `review-code`. There is no documentation co-change
  engine, no document status or verification metadata, and no metrics of pull requests.
- The path classes are `high` and `gate` in the seeded `.claude/path-classes`, which names no
  ecosystem: the `afe-init` skill adds the gate lines of the chosen stack. A path nothing matches
  is normal, or low when it is Markdown or generated (`scripts/lib/classes.sh`).
- Documents are English-only (`.claude/rules/docs.md`); the template has no `docs_language`
  question (from agent-docs-template 0.7.0), on the owner's decision of 2026-11-06.

## 2. Changing the template

1. Edit `template/`, `src/`, and `bin/` only. This repository is itself generated from the
   template: run `scripts/sync-self.sh` to regenerate its template-owned files from the working
   tree, never edit those copies.
2. Add a changeset with `npx changeset`: the bump by section 4 and a summary that names the
   files a project sees change; it becomes the [`CHANGELOG.md`](../CHANGELOG.md) entry, with a
   link to the pull request. A change of `bin/`, `src/`, `template/`, or `package.json` needs one
   (the `changeset` workflow checks it); `npx changeset --empty` when nobody notices it. A
   changeset that adds a rule or a check names the recurring failure it addresses, with the pull
   requests where that failure occurred; a rule or check without one is added only on the owner's
   decision, and the changeset says so (section 6).
3. Run `scripts/check.sh`. Its project part, `scripts/checks.d/10-template.sh`, is the template
   test suite (section 3).
4. Open the pull request with the `create-pr` skill, as in any generated project.

## 3. Tests

`scripts/checks.d/05-cli.sh` runs the unit tests of the command line in `test/*.test.js`: the
questions, their validators and defaults, that a given answer to a removed question is ignored,
the Jinja rendering and conditional names, that every rendered file is template-owned or seeded,
the reading of a Copier answers file, and the warning for a Copier `docs_language` other than
English, none for English.

`scripts/checks.d/15-release.sh` runs `scripts/tag-release.sh` against a local origin: it tags
without a changeset and with only an empty one, and not while a changeset with a release is
pending.

`scripts/checks.d/10-template.sh` runs the template test suite: it sources
[`test/template/lib.sh`](../test/template/lib.sh), then each `test/template/[0-9]*.sh` in name
order into one shell, so a later file reuses the projects and helpers of earlier ones; the
header of each file names what it needs. The groups, by number:

- `10`-`13`: variant A, a GitHub-hosted runner with the default modules, and variant B, a
  self-hosted runner with `code_review` on and `acceptance_check` off, each rendered with the
  command line of the working tree and passing `scripts/check.sh`; each module's files and
  mentions appear only with it. The initial commit on `main` (`--no-git`, an empty clone, a
  forced non-empty directory), and an interactive create that exits after its outro.
- `20`-`25`: the pull request description sections, and the content of the generated skills.
- `30`-`42`: the checks catch violations on variant A (an edited template-owned file, a damaged
  project block, a stale `.claude/settings.json`, a decision record with the wrong number, a
  stale index, a dead link or code path); merge readiness, the path classes and review level of
  `--classes`, the readiness step of the `decisions` workflow on a pull request that a workflow
  opened, and the generated "Gate files" section.
- `60`-`69`: the hooks and the green stamp: what the guard hook asks for, denies, and lets
  through, in sibling and inner worktrees too; the Stop dispatcher (the Ralph cap and its record
  of the capped tree, the fast check, a committed broken document, one combined message, no
  second run on an unchanged green tree, a stamp per kind, a sub-agent in the main session's
  tree, the worktree of the input's `cwd`, a nested repository without the harness); the check
  after every edit; the SessionStart hook;
  the stamp and the quiet output and `--if-changed` of `scripts/check.sh`.
- `70`: in GitHub Actions the hooks run no code of the working tree, the review jobs disable
  them, and every action is pinned to a full commit SHA with its `# v<version>` comment (the
  review checks that the SHA is that version's).
- `80`-`81`: smoke tests of reuse: a documentation-only project with every module off, and a
  Python project with pytest and every module on, where the Acceptance check and the
  fail-without-change driver run (it needs `uvx` and says SKIP without it).
- `90`-`93`: `update` keeps project content (the project block, seeded files, project checks),
  creates a missing seeded file, removes a file the template no longer owns, refuses a dirty
  working tree and a downgrade, reports and replaces a local edit of a template-owned file,
  converts a Copier answers file, and runs the migrations: 0.5.0; 2.0.1, which moves the
  `.harness/` files of a Copier 0.7.0 project into `.claude/`; and 3.0.0 on a project created by
  the 2.1.0 package (the release commit `761f382`, so the suite needs the history of this
  repository).
- `99`: this repository's template-owned files match `template/`.

CI runs both through the `check` workflow, which checks out the full history and sets up
Node.js; the checks run `npm ci` when `node_modules` is missing, and the Python test installs uv
into `~/.local/bin` when `uvx` is missing, so the runner needs only Git and curl besides.

## 4. Versions

Releases are versions of the npm package `create-afe-project`, each with the Git tag
`vMAJOR.MINOR.PATCH` on `main`; `npx create-afe-project@latest update` offers projects the
highest.

| Change | Version part | Examples |
| --- | --- | --- |
| A generated project must act, or its checks start failing | MAJOR | a new required front-matter field, a renamed extension point, a stricter check that existing content can fail |
| New capability that existing projects can adopt without action | MINOR | a new module, a new check that existing content passes, a new skill |
| Correction without new capability | PATCH | wording, a broken link, a script bug |

A release that needs a mechanical change in projects ships a `MIGRATIONS` entry in
`src/config.js` that performs it, and its changeset says what the project must check by hand.
The version part follows the table, not the migration: a migration may ship in any release, such
as the `2.0.1` entry, which restores the harness settings and path classes that the 2.0.0
conversion of a Copier project left in `.harness/`. The `3.0.0` entry replaces a seeded
`.claude/path-classes` that is still a 2.x default (by Git blob hash) with the 3.0.0 default and
warns about a changed one; replaces a `.claude/harness.conf` that is still the 2.x default (by
Git blob hash) with the 3.0.0 default and, in a changed one, sets the caps that still hold the 2.x
defaults to 2; warns that a project's existing documentation map, docs/README.md, is no longer the
template's; and warns, without changing anything, about each tracked file that is not
template-owned and still names a removed document or file (`git ls-files`, a plain substring
match), one line per file and none for a file already warned about; the
answers of the removed questions `docs_review` and `dual_review` are dropped, and those of the
other questions are kept. An update changes an existing seeded file (`SEEDED`) only through a `MIGRATIONS`
entry, and that entry's changeset says so; any other change to a seeded file reaches new projects
only, so its changeset says what an existing project should copy by hand.
Before 1.0.0, MINOR takes the role of MAJOR.

## 5. Release

1. On every push to `main` with pending changesets, the `version` workflow opens or updates the
   Version PR "Release: next version" on `changeset-release/main`: `npm run version-packages`
   consumes the changesets, bumps `package.json` and `package-lock.json`, writes the
   `CHANGELOG.md` section `## X.Y.Z`, and runs `scripts/sync-self.sh`, which also runs the
   migrations of the new version on this repository. It starts the `check` workflow on that
   branch with `workflow_dispatch`, which `GITHUB_TOKEN` may trigger. Whether opening a pull
   request with `GITHUB_TOKEN` starts the `pull_request` workflows is an open question: they
   started on #16, which a `version` run that the owner re-ran opened. The Version PR is exempt
   from the description sections of readiness: its description is generated. The workflows know
   it by its author, `github-actions[bot]`: readiness checks only its decision records, and
   `code-review` skips it, since the action refuses runs a bot starts; readiness prints its gate
   paths for the owner, who reviews them before the merge, as part of the release decision. The
   repository setting "Allow GitHub Actions to create and approve pull requests" must be on, or
   the `version` workflow cannot open the Version PR. With it on, anyone with write access can
   have a workflow open a pull request as `github-actions[bot]` and so skip the description
   sections and the reviews; the owner, who merges every pull request, sees the author.
2. Before merging it, the review of section 6 runs, and its proposals go to the owner. Merging
   the Version PR is the owner's release decision.
3. The push of that merge finds no changeset pending (an empty changeset counts as none: it
   releases nothing, and the action opens no Version PR for it): `scripts/tag-release.sh` tags `vX.Y.Z` and
   starts the `release` workflow on the tag. It reads the changesets with `@changesets/parse`,
   which the pinned `@changesets/cli` installs (`npm ci`), and fails without tagging when a
   changeset does not parse. The workflow checks that the tag is on `main` and
   that `package.json` and the `CHANGELOG.md` section are at `X.Y.Z`, runs the package tests,
   publishes a GitHub release with that section as its notes, then the package to npm by trusted
   publishing: the package settings on npmjs.com name this repository and `release.yml`, and npm
   takes a short-lived OIDC token from the run, so no npm token is stored. A tag pushed by hand
   releases the same way.
4. Projects update with their `update-template` skill.

## 6. Pruning

Rules and checks are scaffolding that has to earn its keep: a failure is diagnosed, encoded as a
rule or a check, and a rule or check that catches nothing is removed. There are no metrics of
pull requests.

- At each release, the maintainer reads the "Checks" sections and the review findings of the pull
  requests merged since the previous release, in this repository and in the generated projects
  the maintainer can read.
- A rule or a check that neither fired nor caught anything over the period is proposed for
  removal to the owner, in its own pull request; the owner decides.
- A new rule or check names the recurring failure it addresses (section 2), so that the next
  review can tell whether it still occurs.
