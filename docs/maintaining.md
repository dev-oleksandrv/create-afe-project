# Maintaining the template

How the template is changed, tested, versioned, and released. Questions, seeded files, tasks,
and migrations are in [`src/config.js`](../src/config.js); the command line that creates and
updates projects is [`bin/create-afe-project.js`](../bin/create-afe-project.js) with
[`src/`](../src/); the rules a generated project follows are in [`template/`](../template/).

## 1. Model

- `template/` is the product. Every file in it is template-owned (listed in
  [`template/.template/owned.txt.jinja`](../template/.template/owned.txt.jinja)), seeded (listed
  as `SEEDED` in `src/config.js`), or generated: the answers file by the command line, the
  ownership manifest and the decision index by the `TASKS` of `src/config.js`. Files render
  with Nunjucks, which reads the Jinja syntax: a `.jinja` file is rendered and loses the suffix,
  a path segment that renders empty drops the file, and `_gitignore` becomes `.gitignore`,
  because npm never publishes a `.gitignore`. The classes are
  defined in the generated `docs/documentation-rules.md`, section 9.
- This repository's own `.afe-answers.json` records the version of `package.json`: its
  template-owned files come from the working tree of `template/` through `scripts/sync-self.sh`,
  which runs the `update` command of this working tree, not from a release.
- A project extends the template only at the extension points of that section:
  `scripts/checks.d/`, `.claude/hooks/project/stop/`, `.claude/path-classes`,
  `.claude/harness.conf`, `.claude/settings.project.json`, the project block of `AGENTS.md`, and
  its own documents. A need that the extension points do not cover is a
  change of the template, not a local edit.
- Optional parts are modules behind a question of `src/config.js` (today: `docs_review`, `code_review`,
  `dual_review`, `secret_scan`, `acceptance_check`, and `fail_without_change`). A module's
  files use a conditional file name, and the documents mention the module only inside the same
  condition.

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

`scripts/checks.d/05-cli.sh` runs the unit tests of the command line in `test/`: the questions,
their validators and defaults, the Jinja rendering and conditional names, that every rendered
file is template-owned or seeded, and the reading of a Copier answers file.
`scripts/checks.d/15-release.sh` runs `scripts/tag-release.sh` against a local origin: it tags
without a changeset and with only an empty one, and not while a changeset with a release is
pending; and that such a changeset, which has no heading, passes markdownlint through
`.changeset/.markdownlint.jsonc` with the other rules still on, and that this file stays the root
configuration plus `MD041: false`.
`scripts/checks.d/10-template.sh` is the template test suite. It renders the template with the
command line of the working tree in four projects and runs `scripts/check.sh` in each, the line budgets of the rule documents included:

- variant A, a GitHub-hosted runner with the default modules (`docs_review` and `code_review`
  on), and variant B, a self-hosted runner with the opposite and `dual_review` on; each module's
  files and mentions appear only with it;
- a smoke test of reuse: a documentation-only project with every module off, where readiness and
  `--classes` work on a document change and no module script exists; and a Python project with
  pytest and every module on, where the Acceptance check finds an identifier in a test and misses
  one that no test carries, and the fail-without-change driver accepts a new test that fails on
  the base, rejects a changed test that passes there unless `--allow-pass-on-base` is given,
  checks a renamed test file, and leaves no worktree behind; the module's workflow runs the
  driver. The Python part needs `uvx` to provision pytest and says SKIP
  without it.

Every project is created with the initial commit of the command line on `main`; it also proves
that `--no-git` makes none, that an empty clone gets it on `main`, and that a non-empty
directory written with `--force` is never committed. On variant A it proves that the checks reject an edited template-owned file, a damaged project
block, a rule document over its budget, a stale `.claude/settings.json`, a decision record with
the wrong number, and a stale index; that a description in the template's sections passes
readiness, and the forms readiness rejects (no Acceptance, an Acceptance item without an
existing path (a root-level test file counts, a version does not), no Metrics, a Metrics row
outside its forms, unanswered findings, a blocker as a limit, a missing or repeated measure (`Regression of` included), an added owner marker in a Markdown file or a touched gate file that
the description does not name); the class of each kind of path and the review level of
`--classes` (`contracts/` is high; dependency updates, pre-commit hooks, task runners, and tool
versions are gate, each line of their block with a file it matches); the totals, distributions, regression rate, and hours to
merge of `scripts/pr-metrics.sh` against a stand-in for `gh`, and its warning when `--limit`
cuts the period; and which edits and commands the protect hook asks for (class
approval, an `approval` line over a built-in allowance, secrets, the irreversible commands it
names, behind `cd DIR`, `git -C DIR`, or in an interpreter's heredoc) and which it lets through
(gate, high, and normal paths, an ordinary push, heredoc text); that a Stop hook stops blocking
at the Ralph cap and counts again afterwards; that a large change only warns; that
`scripts/env.sh` skips an unset command and passes on a set one's exit code; and that the
settings deny reading secrets. It also checks that the protect hook asks before publishing a
package or an image, `gh workflow run`, a `gh api` DELETE, a change of repository settings
(`scripts/protect-branch.sh` without `--dry-run`, a `gh api` write on the repository, its
rulesets, or a branch protection, but not the replies and reads of the `create-pr` skill), and
an edit or command with a known token format, and denies a push to `main` once the remote has it; that the check after every edit
runs `CHECK_EDIT` on matching files inside the project only, a relative path resolved against the
input's `cwd`; that conventions, recipes, and operations
carry `verified-against`, that the map's conventions row links section 2, and that docs-review
reads the document kinds and reports a convention or recipe copied into a skill or tool-specific
rule file and a convention without its check or `none`, and review-code applies the conventions; that the testing rules carry the
rule that a flaky test is fixed, never retried or rerun until green, and that skipping one is a
blocker; that the rubric of variant A has the
"Dependencies" row and the `review-code` skill lists dependencies among its criteria and says
what to check for an added one; that the `create-pr` skill takes
findings only from the review bot and the repository's owner, members, and collaborators; that the readiness step of the `decisions` workflow, run as
written, checks only the decision records of a pull request that `github-actions[bot]` opened and
still fails a person's empty description, and that the AI reviews skip such a pull request; that the SessionStart hook prints at
most ten lines of local state (the branch, its base and the commits ahead, uncommitted and
untracked files, merge conflicts, plans and their `review-by`, past ones first and counted when
not shown), only the plans outside a repository, and nothing in an empty directory; that the fast Stop hook runs
`CHECK_FAST` only for a change to a file other than Markdown, never as the default, blocks on a
failure, and lets the agent stop during a merge conflict; that in GitHub Actions every hook but
the protect hook exits 0 before it runs a script of the working tree or a project Stop hook, the
protect hook still asks and runs no such script, and the review jobs disable all hooks; that a
hook command whose script is
missing fails the template check; that the link check finds a missing file or anchor; that
`scripts/protect-branch.sh --dry-run` prints the repository settings (merge commits only, head
branches deleted, secret scanning) and the ruleset, that `--require-base` adds the `base` job only
with its module and an update keeps it, and that a live run against a stand-in for `gh` goes on past secret
scanning the plan refuses, still applies the ruleset and then fails after any other secret-scanning
error, ends without error when the plan offers no rulesets, and finds its ruleset on a later page
and not one inherited from an organisation; that the `secret-scan` workflow
appears only with its module; and that every action of the workflows of variant A and of the Python project is
pinned to an exact version or a commit. It also checks that `update` keeps project content (the project
block, seeded files, project checks), creates a missing seeded file, removes a file the template
no longer owns, refuses a dirty working tree and a downgrade, reports and replaces a local edit
of a template-owned file, converts a Copier answers file, and runs the 0.5.0 migration; and that
this repository's template-owned files match `template/`. CI runs both through the `docs`
workflow, which sets up Node.js; the checks run `npm ci` when `node_modules` is missing, and the
Python test installs uv into `~/.local/bin` when `uvx` is missing, so the runner needs only Git
and curl besides.

## 4. Versions

Releases are versions of the npm package `create-afe-project`, each with the Git tag
`vMAJOR.MINOR.PATCH` on `main`; `npx create-afe-project@latest update` offers projects the
highest.

| Change | Version part | Examples |
| --- | --- | --- |
| A generated project must act, or its checks start failing | MAJOR | a new required front-matter field, a renamed extension point, a stricter check that existing content can fail |
| New capability that existing projects can adopt without action | MINOR | a new module, a new check that existing content passes, a new skill |
| Correction without new capability | PATCH | wording, a broken link, a script bug |

A MAJOR release that needs a mechanical change in projects ships a `MIGRATIONS` entry in
`src/config.js` that performs it, and its changeset says what the project must check by hand.
An update never changes an existing seeded file (`SEEDED`): a change to them reaches new projects
only, so its changeset says what an existing project should copy by hand.
Before 1.0.0, MINOR takes the role of MAJOR.

## 5. Release

1. On every push to `main` with pending changesets, the `version` workflow opens or updates the
   Version PR "Release: next version" on `changeset-release/main`: `npm run version-packages`
   consumes the changesets, bumps `package.json` and `package-lock.json`, writes the
   `CHANGELOG.md` section `## X.Y.Z`, and runs `scripts/sync-self.sh`. It starts the `docs`
   workflow on that branch with `workflow_dispatch`, which `GITHUB_TOKEN` may trigger. Whether
   opening a pull request with `GITHUB_TOKEN` starts the `pull_request` workflows is an open
   question: they started on #16, which a `version` run that the owner re-ran opened. The
   Version PR is exempt from the description sections of readiness: its description is generated.
   The workflows know it by its author, `github-actions[bot]`: readiness checks only its decision
   records, and `docs-review` and `code-review` skip it, since the action refuses runs a bot
   starts; readiness prints its gate and approval paths for the owner, who reviews them before the
   merge, as part of the release decision. The repository setting "Allow GitHub Actions to create
   and approve pull requests" must be on, or the `version` workflow cannot open the Version PR.
   With it on, anyone with write access can have a workflow open a pull request as
   `github-actions[bot]` and so skip the description sections and the reviews; the owner, who
   merges every pull request, sees the author.
2. Before merging it, the measurement of section 6 runs, and its proposals go to the owner.
   Merging the Version PR is the owner's release decision.
3. The push of that merge finds no changeset pending (an empty changeset counts as none: it
   releases nothing, and the action opens no Version PR for it): `scripts/tag-release.sh` tags `vX.Y.Z` and
   starts the `release` workflow on the tag. It reads the changesets with `@changesets/parse`,
   which the pinned `@changesets/cli` installs (`npm ci`), and fails without tagging when a
   changeset does not parse. The workflow checks that the tag is on `main` and
   that `package.json` and the `CHANGELOG.md` section are at `X.Y.Z`, runs the package tests,
   publishes a GitHub release with that section as its notes, then the package to npm with the
   repository secret `NPM_TOKEN`. A tag pushed by hand releases the same way.
4. Projects update with their `update-template` skill (the generated `docs/contributing.md`,
   section 5).

## 6. Measurement and pruning

Rules and checks are scaffolding that has to earn its keep: a failure is diagnosed, encoded as a
rule or a check, and measured, and a rule or check that catches nothing is removed.

- At each release, the maintainer runs `scripts/pr-metrics.sh --since <date of the previous
  release>` in this repository and with `--repo owner/name` in the generated projects the
  maintainer can read. It sums the "Metrics" sections of the merged pull requests (the generated
  `docs/contributing.md`, section 3) by sensor, and names the sensors without a finding.
- A rule or a check that neither fired nor caught anything over the period, by these metrics and
  by the failures quoted under "Checks", is proposed for removal to the owner, in its own pull
  request; the owner decides. A pull request without a "Metrics" section is counted, not read.
- A new rule or check names the recurring failure it addresses (section 2), so that the next
  measurement can tell whether it still occurs.
