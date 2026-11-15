# create-afe-project

An npm package that creates agent-friendly repositories and keeps them up to date. A generated
project holds what is true in it and what an agent may not do: one check command that runs the
same way locally and in CI, a fast check after every edit, hooks and permission rules that hold
the limits, short rules for tests and documents, and a place for how to run the product. How an
agent works on a task comes from the developer's own setup. It implements the pillars of
[Agent-Friendly Engineering](https://github.com/dev-oleksandrv/afe/blob/main/GUIDE.md). Repository:
`dev-oleksandrv/create-afe-project`; it started as a fork of the Copier template
`xandronak/agent-docs-template`.

## What a generated project gets

| Part | Files |
| --- | --- |
| Agent rules | `AGENTS.md` with one project block (what the project is, how to run it and see a change), `CLAUDE.md` |
| Testing and documentation rules, loaded when a matching file is touched | `.claude/rules/testing.md`, `.claude/rules/docs.md` |
| Decision records | `docs/decisions/adr-template.md`; a record is accepted when written |
| Checks and environment | `scripts/check.sh` and the scripts it runs, the link check `scripts/check-links.mjs` included; `scripts/env.sh` for the environment commands; `scripts/protect-branch.sh` for the repository settings and the GitHub ruleset of `main` |
| Limits | `.claude/settings.json` (generated) with deny and ask rules; `.claude/hooks/`: the guard hook (no push to the default branch, a prompt before a known secret format), the SessionStart hook, the check after every edit; `.claude/risky-paths` |
| Skills | `.claude/skills/`: `afe-init`, `update-template`, optional `review-code` |
| CI | `.github/workflows/` (`check`, optional `secret-scan` and `code-review`) |

Every file has one owner: the template (the files that `.template/owned.txt` lists), the
project (seeded files, created once), or a generator; [`src/config.js`](src/config.js) lists the
seeded and the generated files.

## Requirements

Node.js 20 or later with npm, Git, and bash. A generated project needs nothing more: its hooks
and checks, the link check included, run on Node.js.

## Create a project

```bash
npm create afe-project@latest <directory>
# or
npx create-afe-project@latest <directory>
```

The wizard asks about the project and which optional checks to turn on
([`src/config.js`](src/config.js) lists the questions), then writes the generated files and
prints the next steps. Without a terminal, or with `--defaults`, it takes answers from `--data key=value` and
`--data-file answers.json`, then the defaults:

```bash
npx create-afe-project@latest acme --defaults --data project_name=acme \
  --data 'project_description=A sample project.' --data github_repo=acme/acme
```

`npx create-afe-project --help` lists every option.

## Update a project

In the project, the `update-template` skill does it: a branch from a clean `main`, then

```bash
npx create-afe-project@latest update --defaults
```

It replaces the template-owned files, keeps the project block of `AGENTS.md`, creates missing
seeded files and changes existing ones only by a migration, runs the migrations between the two
versions, and regenerates the generated files; then the checks and a pull request. A project
still on the Copier template, or below 2.0.1 with `.harness/` files, updates with
`create-afe-project@3` first.

## Versions

Releases are npm versions, tagged `vMAJOR.MINOR.PATCH` in Git and described in [`CHANGELOG.md`](CHANGELOG.md).
How versions are chosen and released: [`docs/maintaining.md`](docs/maintaining.md).

## License

[MIT](LICENSE).
