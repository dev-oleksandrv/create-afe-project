# Maintaining the template

How the template is changed, tested, versioned, and released. Questions and file lists are in
[`copier.yml`](../copier.yml); the rules a generated project follows are in
[`template/`](../template/).

## 1. Model

- `template/` is the product. Every file in it is template-owned (listed in
  [`template/.template/owned.txt.jinja`](../template/.template/owned.txt.jinja)), seeded (listed
  under `_skip_if_exists` in `copier.yml`), or generated: the answers file by Copier itself, the
  ownership manifest and the decision index by the `_tasks` of `copier.yml`. The classes are
  defined in the generated `docs/documentation-rules.md`, section 9.
- This repository's own `.copier-answers.yml` has no `_commit`: its template-owned files come from
  the working tree of `template/` through `scripts/sync-self.sh`, not from a release.
- A project extends the template only at the extension points of that section:
  `scripts/checks.d/`, `.claude/hooks/project/stop/`, `.claude/protected-paths`, the project
  block of `AGENTS.md`, and its own documents. A need that the extension points do not cover is a
  change of the template, not a local edit.
- Optional parts are modules behind a `copier.yml` question (today: `docs_review`, `code_review`, and `dual_review`). A module's
  files use a conditional file name, and the documents mention the module only inside the same
  condition.

## 2. Changing the template

1. Edit `template/` and `copier.yml` only. This repository is itself generated from the
   template: run `scripts/sync-self.sh` to regenerate its template-owned files from the working
   tree, never edit those copies.
2. Add an entry under `## [Unreleased]` in [`CHANGELOG.md`](../CHANGELOG.md), in the section
   that matches its effect (Added, Changed, Fixed, Removed), naming the files a project sees
   change.
3. Run `scripts/check.sh`. Its project part, `scripts/checks.d/10-template.sh`, is the template
   test suite (section 3).
4. Open the pull request with the `create-pr` skill, as in any generated project.

## 3. Tests

`scripts/checks.d/10-template.sh` renders the template twice (a GitHub-hosted runner with the
default modules, `docs_review` and `code_review` on and `dual_review` off, and a self-hosted
runner with the opposite), checks that each module's files and mentions appear only with it, runs `scripts/check.sh` in each
rendering, checks the sections of the pull request description template in each rendering and
that the readiness check accepts a description written in them, proves that the checks reject an edited template-owned file, a damaged project block, a
decision record with the wrong number, and a stale index, and confirms that this repository's
template-owned files match `template/`. CI runs it through the `docs` workflow, which sets up
Node.js and lychee; the test installs uv into `~/.local/bin` when neither Copier nor `uvx` is
present, so the runner needs only Git, curl, and jq.

## 4. Versions

Releases are Git tags `vMAJOR.MINOR.PATCH` on `main`. Copier offers projects the highest tag.

| Change | Version part | Examples |
| --- | --- | --- |
| A generated project must act, or its checks start failing | MAJOR | a new required front-matter field, a renamed extension point, a stricter check that existing content can fail |
| New capability that existing projects can adopt without action | MINOR | a new module, a new check that existing content passes, a new skill |
| Correction without new capability | PATCH | wording, a broken link, a script bug |

A MAJOR release that needs a mechanical change in projects ships a `_migrations` entry in
`copier.yml` that performs it, and its changelog entry says what the project must check by hand.
An update never touches seeded files (`_skip_if_exists`): a change to them reaches new projects
only, so its changelog entry says what an existing project should copy by hand.
Before 1.0.0, MINOR takes the role of MAJOR.

## 5. Release

1. A release pull request renames `## [Unreleased]` in `CHANGELOG.md` to
   `## [X.Y.Z] - YYYY-MM-DD`, adds a fresh empty `## [Unreleased]`, and is merged by the owner.
2. The owner, or an agent on the owner's instruction, tags the merge commit and pushes the tag:
   `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.
3. The `release` workflow checks that `CHANGELOG.md` has the section `## [X.Y.Z]` and that the
   tag is on `main`, then publishes a GitHub release with that section as its notes.
4. Projects update with their `update-template` skill (the generated `docs/contributing.md`,
   section 5).
