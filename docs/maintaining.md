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
  `scripts/checks.d/`, `.claude/hooks/project/stop/`, `.claude/path-classes`,
  `.claude/harness.conf`, `.claude/settings.project.json`, the project block of `AGENTS.md`, and
  its own documents. A need that the extension points do not cover is a
  change of the template, not a local edit.
- Optional parts are modules behind a `copier.yml` question (today: `docs_review`, `code_review`,
  `dual_review`, `acceptance_check`, and `fail_without_change`). A module's
  files use a conditional file name, and the documents mention the module only inside the same
  condition.

## 2. Changing the template

1. Edit `template/` and `copier.yml` only. This repository is itself generated from the
   template: run `scripts/sync-self.sh` to regenerate its template-owned files from the working
   tree, never edit those copies.
2. Add an entry under `## [Unreleased]` in [`CHANGELOG.md`](../CHANGELOG.md), in the section
   that matches its effect (Added, Changed, Fixed, Removed), naming the files a project sees
   change. An entry that adds a rule or a check names the recurring failure it addresses, with
   the pull requests where that failure occurred; a rule or check without one is not added
   (section 6).
3. Run `scripts/check.sh`. Its project part, `scripts/checks.d/10-template.sh`, is the template
   test suite (section 3).
4. Open the pull request with the `create-pr` skill, as in any generated project.

## 3. Tests

`scripts/checks.d/10-template.sh` is the template test suite. It renders the template in four
projects and runs `scripts/check.sh` in each, the line budgets of the rule documents included:

- variant A, a GitHub-hosted runner with the default modules (`docs_review` and `code_review`
  on), and variant B, a self-hosted runner with the opposite and `dual_review` on; each module's
  files and mentions appear only with it;
- a smoke test of reuse: a documentation-only project with every module off, where readiness and
  `--classes` work on a document change and no module script exists; and a Python project with
  pytest and every module on, where the Acceptance check finds an identifier in a test and misses
  one that no test carries, and the fail-without-change driver accepts a new test that fails on
  the base, rejects a changed test that passes there unless `--allow-pass-on-base` is given,
  checks a renamed test file, and leaves no worktree behind. The Python part needs `uvx` to provision pytest and says SKIP
  without it.

On variant A it proves that the checks reject an edited template-owned file, a damaged project
block, a rule document over its budget, a stale `.claude/settings.json`, a decision record with
the wrong number, and a stale index; that a description in the template's sections passes
readiness, and the forms readiness rejects (no Acceptance, an Acceptance item without an
existing path (a root-level test file counts, a version does not), no Metrics, a Metrics row
outside its forms, unanswered findings, a blocker as a limit, a missing or repeated measure, an added owner marker in a Markdown file or a touched gate file that
the description does not name); the class of each kind of path and the review level of
`--classes`; the totals of `scripts/pr-metrics.sh` against a stand-in for `gh`, and its warning
when `--limit` cuts the period; and which edits and commands the protect hook asks for (class
approval, an `approval` line over a built-in allowance, secrets, the irreversible commands it
names) and which it lets through (gate, high, and normal paths, an ordinary push); and that a
Stop hook stops blocking at the Ralph cap and counts again afterwards. It also checks that `copier update` keeps project content
and that this repository's template-owned files match `template/`. CI runs it through the `docs`
workflow, which sets up Node.js and lychee; the test installs uv into `~/.local/bin` when
neither Copier nor `uvx` is present, so the runner needs only Git, curl, and jq.

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

1. Before the release, the measurement of section 6 runs, and its proposals go to the owner.
   A release pull request renames `## [Unreleased]` in `CHANGELOG.md` to
   `## [X.Y.Z] - YYYY-MM-DD`, adds a fresh empty `## [Unreleased]`, and is merged by the owner.
2. The owner, or an agent on the owner's instruction, tags the merge commit and pushes the tag:
   `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.
3. The `release` workflow checks that `CHANGELOG.md` has the section `## [X.Y.Z]` and that the
   tag is on `main`, then publishes a GitHub release with that section as its notes.
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
