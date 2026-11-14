# Maintaining the template

How the template is changed, tested, versioned, and released. Each fact has one place: what a
file does is in its header, and this document holds the model and the procedures. The command
line is [`bin/create-afe-project.js`](../bin/create-afe-project.js) with [`src/`](../src/); the
product is [`template/`](../template/).

## 1. Model

- Every file of `template/` has one owner. Template-owned files are listed in
  [`template/.template/owned.txt.jinja`](../template/.template/owned.txt.jinja): an update
  replaces them. Seeded files (`SEEDED` in [`src/config.js`](../src/config.js)) are created once
  and then belong to the project. Generated files (`TASKS`) are rebuilt after every create and
  update. How names and `.jinja` files render is in the header of `src/render.js`.
- This repository is generated from its own template: `scripts/sync-self.sh` runs the `update`
  command of the working tree, so its `.afe-answers.json` records the version of `package.json`.
- A project extends the template only at its extension points: `scripts/checks.d/`,
  `.claude/path-classes`, `.claude/harness.conf`, `.claude/settings.project.json` (its own
  hooks and permission rules), the project block of `AGENTS.md`, and its own documents. A need
  that the extension points do not cover is a change of the template, not a local edit.
- Optional parts are modules behind a question of `src/config.js`. A module's files use a
  conditional file name, and the documents mention the module only inside the same condition.
- What a generated project runs is described in the header of each file: the checks in
  `template/scripts/`, the hooks in `template/.claude/hooks/`, the permission rules in
  `template/.claude/settings.template.json`, and the skills in `template/.claude/skills/`.
- Documents are English-only (`.claude/rules/docs.md`), on the owner's decision of 2026-11-06.

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

`scripts/check.sh` runs the checks of `scripts/checks.d/`: the unit tests of the command line in
`test/*.test.js`, the template test suite, and the tests of `scripts/tag-release.sh`.

The template suite sources [`test/template/lib.sh`](../test/template/lib.sh), then each
`test/template/[0-9]*.sh` in name order into one shell, so a later file reuses the projects and
helpers of earlier ones. The header of each file says what it tests and what it needs; a new
test goes into the file of its subject.

CI runs them through the `check` workflow. The suite needs Node.js, Git, curl, and the full
history of this repository: the 3.0.0 migration test builds the 2.1.0 package from its release
commit, and the Python smoke test installs uv when `uvx` is missing.

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
`src/config.js`, which describes it, and its changeset says what the project must check by hand.
The version part follows the table, not the migration. An update changes an existing seeded file
only through a `MIGRATIONS` entry; any other change to a seeded file reaches new projects only,
so its changeset says what an existing project should copy by hand. The package keeps the
migrations from 3.0.0 on: an older project that still has a Copier answers file or `.harness/`
files updates with `create-afe-project@3` first.

## 5. Release

1. A push to `main` with pending changesets makes the `version` workflow open or update the
   Version PR "Release: next version". It needs the repository setting "Allow GitHub Actions to
   create and approve pull requests".
2. The owner approves the workflow runs of the Version PR on its page: the runs of a pull
   request opened with `GITHUB_TOKEN` wait for that, the required check `integrity` among them.
3. Before merging it, the review of section 6 runs, and its proposals go to the owner. Merging
   the Version PR is the owner's release decision.
4. The push of that merge tags `vX.Y.Z` and starts the `release` workflow, which publishes the
   GitHub release and the npm package by trusted publishing, so no npm token is stored. A tag
   pushed by hand releases the same way.
5. Projects update with their `update-template` skill.

The details are in the headers of `.github/workflows/version.yml`,
`.github/workflows/release.yml`, and `scripts/tag-release.sh`. One thing they do not say: the
workflows know the Version PR by its author, `github-actions[bot]`, and exempt it from the
description sections and the reviews. With the repository setting above, anyone with write access
can have a workflow open such a pull request; the owner, who merges every pull request, sees the
author.

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
