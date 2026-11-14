---
"create-afe-project": major
---

4.0.0 removes parts that cost more than they caught, on the owner's decision.

- Guard hook: `.claude/hooks/guard.sh` only denies a push to the default branch and asks before
  a known token format. The irreversible commands (a merge, a release, a change of repository
  settings, publishing) are `permissions.ask` rules of `.claude/settings.template.json`; an edit
  of `AGENTS.md` no longer prompts, since `scripts/check-template.sh` fails on a changed template
  part. No longer prompted: `git push origin v1.2.3` without `refs/tags/`, a `gh api` write to
  `repos/OWNER/REPO` itself, and a command behind `git -C`. A project drops a rule with `remove`
  in `.claude/settings.project.json`.
- Update: the package keeps the migrations from 3.0.0 on and no longer reads a Copier answers
  file; a project with `.copier-answers.yml` or `.harness/` files runs
  `npx create-afe-project@3 update` first. The report no longer lists replaced local edits: the
  `update-template` skill runs `scripts/check-template.sh` before the update.
- By hand: a project with `.claude/hooks/project/stop/*.sh` registers them under `hooks.Stop` in
  `.claude/settings.project.json`, since the Stop dispatcher no longer runs them; and it deletes
  `FWC_INSTALL` and `FWC_CLASSIFIER` from `.claude/harness.conf`, since the fail-without-change
  driver installs with `SETUP`.
- Shorter header comments in `stop-dispatch.sh` and `protect-branch.sh`, and a shorter seeded
  `README.md` for new projects; no change of behaviour.
