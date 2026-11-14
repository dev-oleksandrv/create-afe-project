---
"create-afe-project": major
---

4.0.0 removes parts that cost more than they caught, on the owner's decision: the shell-command
parser and the `AGENTS.md` prompt of the guard hook, the conversion of Copier projects with the
migrations before 3.0.0, and a few unused settings.

- Guard hook: `.claude/hooks/guard.sh` now only denies a push to the default branch and asks
  before a known token format. It no longer asks before an edit of `AGENTS.md`:
  `scripts/check-template.sh` fails on a changed template part, and the project block may change.
  It no longer parses shell commands for irreversible actions: `.claude/settings.template.json`
  carries them as `permissions.ask` rules (a push of tags, `gh pr merge`, `gh release`,
  `gh repo edit` and the like, `gh workflow run`, `gh api` with `DELETE`, `graphql`, `rulesets`,
  or `protection`, `scripts/protect-branch.sh`, and publishing a package or an image), which
  `.claude/settings.json` gets on the update. Three cases the hook caught now pass without a
  prompt: `git push origin v1.2.3` without `refs/tags/`, a `gh api` write to `repos/OWNER/REPO`
  itself, and a command behind `git -C`; a read through `gh api graphql` or of the rulesets, and
  `scripts/protect-branch.sh --dry-run`, now prompt. A project drops a rule it does not want
  with `remove` in `.claude/settings.project.json`.
- Update: a project that still has a Copier answers file (`.copier-answers.yml`), `.harness/`
  files, or the `.claude/protected-paths` of a release before 0.5.0 updates with
  `npx create-afe-project@3 update` first; this package no longer reads the Copier answers file
  and keeps the migrations from 3.0.0 on. The package no longer depends on `yaml`.
- Update: the report no longer lists replaced local edits of template-owned files. The
  `update-template` skill runs `scripts/check-template.sh` before the update instead, which names
  each of them.
- Stop dispatcher: `.claude/hooks/stop-dispatch.sh` no longer runs
  `.claude/hooks/project/stop/*.sh`. A project that has such a hook registers it under
  `hooks.Stop` in `.claude/settings.project.json` by hand.
- fail-without-change: `FWC_INSTALL` and `FWC_CLASSIFIER` are gone; the driver installs on the
  base with `SETUP`. Delete both lines from an existing `.claude/harness.conf` by hand; a project
  that set `FWC_INSTALL` moves its command to `SETUP`.
- `scripts/lib/json.mjs` loses the commands `ask` and `deny`, which nothing called.
