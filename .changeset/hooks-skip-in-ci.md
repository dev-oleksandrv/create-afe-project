---
"create-afe-project": patch
---

Security: the `code-review` and `docs-review` workflows ran code of the pull request next to
`CLAUDE_CODE_OAUTH_TOKEN` and `id-token: write`. claude-code-action restores `.claude/` from the
base branch but leaves every other file at the pull request's head, so the base hooks ran the
head's `scripts/lib/json.mjs`, `scripts/lib/git-base.sh`, `scripts/lib/harness-conf.sh`,
`scripts/check-*.sh`, `scripts/env.sh fast`, `CHECK_EDIT`, and the project's Stop hooks in
`.claude/hooks/project/stop/`. Now every hook in `.claude/hooks/`, `protect-docs.sh` included
(it runs `scripts/lib/json.mjs`, which writes its answer, so a pull request would decide it
anyway), exits 0 at its first command when `GITHUB_ACTIONS` is set, and both review workflows
pass `--settings '{"disableAllHooks": true}'` in `claude_args`, which outranks the project
settings and also covers hooks a project adds in `.claude/settings.project.json`.
`docs/documentation-rules.md`, section 7, says so. Claude Code sessions outside GitHub Actions
are unchanged; a project that runs Claude Code in its own workflows no longer gets the harness
hooks there. An update applies the change to the template-owned hooks, workflows, and rules;
nothing is to do by hand. Ported from agent-docs-template 0.9.0, adapted to this template, from
the 2.0.0 review on the owner's instruction of 2026-11-06.
