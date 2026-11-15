---
"create-afe-project": minor
---

Skills, rules, settings, and workflows after the harness review of November 2026; no check of an
existing project starts failing.

- Secrets: `.claude/settings.template.json` keeps `Read(**/.env.*)` and carves `.env.example` out
  with `Read(!.env.example)`; `afe-init` no longer takes the wildcard out, which had opened
  `.env.local`, `.env.production`, and every other variant (one project then listed twelve by
  hand). A project that has `"Read(**/.env.*)"` under `remove` in
  `.claude/settings.project.json` deletes that entry and its hand-made list, then runs
  `scripts/gen-settings.sh`.
- `/create-pr` (`.claude/skills/create-pr/SKILL.md`): on a branch that already has a pull request
  it runs every step and edits that one; `--review-evidence <file>` takes an external review when
  `scripts/check-review-evidence.mjs` accepts it for HEAD; an open blocker, a failed or partial
  review, or a waived failed check (written as `Exception accepted: <check>, <sha>, <who and
  when>`) keeps the pull request a draft and the report "Not ready to merge", and a draft with
  nothing waiting is marked ready. More than ten identifiers are grouped in "Acceptance and test
  plan".
- CI review (`code_review` module): in one generated project 41 of 95 merged pull requests had a
  CI review only on an earlier commit (pull requests 42, 140, and 154 there), and the summaries of
  pull requests 159 and 160, shown as the login `claude`, fell outside the comment filter.
  `/create-pr` now names the commit the review ran on, says "Not ready to merge" when later
  commits change more than documents, starts the review once more on the last commit by turning
  the pull request into a draft and back (`gh pr ready --undo`, then `gh pr ready`, which fires
  the existing `ready_for_review` trigger), and takes the findings of the run that posted them. The workflow gives `review-code` the base
  branch's `AGENTS.md` and the files its project block names, and puts the base `AGENTS.md` in
  the checkout, so a pull request's own `AGENTS.md` or criteria file is reviewed as data, not
  followed; `review-code` ends with which changed files it read.
- `review` skill: Codex runs with `--ephemeral --ignore-rules`. The rubric
  (`.claude/skills/review/rubric.md`) makes a duplicate test a suggestion to merge, and needs no
  test for a clause that a test at another level covers.
- New question `licence_check` (default off): only with it do the rubric's Dependencies criterion,
  `afe-init`, and `review-code` name licences; the owner had removed that criterion by hand in two
  projects. An existing project that wants it updates with `--data licence_check=true`.
- `afe-init`: asks whether to turn on the Claude Code sandbox and, on yes, writes the `sandbox`
  block into `.claude/settings.project.json`, with what the sandbox does not cover; every
  deployable part gets one smoke test at every stage (one project shipped a 6,000-line web app
  without one), and `E2E` is set or the pull request says why not.
- Rules: `AGENTS.md` lets a change update a document that it makes false, which the old rule
  forbade; it asks a test of new behaviour or of a fix to fail on the base for the intended
  reason, and points every agent, not only Claude Code, at `.claude/rules/testing.md` and
  `.claude/rules/docs.md`. `.claude/rules/testing.md` keeps the regression test first for every
  defect and scopes test-first and an independent author of acceptance tests to class high; a
  named invariant or characterization test may pass on the base, as tests of that project's pull
  request 160 rightly did against the literal rule. "Gate files" is information for the
  owner, not a control.
- New projects only, since `README.md` is seeded: a "Sandbox" section, the `licence_check` module,
  the second CI review of the last commit, the `--review-evidence` flag, and the statement that without the
  ruleset nothing on the server stops the merge of an unchecked commit. An existing project may
  copy them by hand.
