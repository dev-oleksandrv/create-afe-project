# agent-docs-template

A [Copier](https://copier.readthedocs.io/) template for agent-friendly repositories. It gives a new
project its documentation rules, short decision records with a generated index, contribution and
pull request rules, checks that run the same way locally, in Claude Code hooks, and in CI, and the
Claude Code skills that apply them. Repository: `xandronak/agent-docs-template`.

## What a generated project gets

| Part | Files |
| --- | --- |
| Agent rules | `AGENTS.md` with one project block, `CLAUDE.md` |
| Documentation rules, statuses, and file ownership | `docs/documentation-rules.md`, `docs/README.md` |
| Branches, commits, pull requests, template updates | `docs/contributing.md` |
| Decision records | `docs/decisions/adr-template.md`, a generated `docs/decisions/README.md` |
| Checks | `scripts/check.sh` and the scripts it runs |
| Claude Code hooks and skills | `.claude/settings.json`, `.claude/hooks/`, `.claude/skills/` (`create-pr`, `update-template`, optional `docs-review`) |
| CI | `.github/workflows/` (`docs`, `decisions`, optional `docs-review`) |

Every file has one owner: the template, the project, or a generator. The rules are in
[`template/docs/documentation-rules.md.jinja`](template/docs/documentation-rules.md.jinja),
section 9.

## Requirements

Copier 9.4 or later (`uv tool install copier`), Git, Node.js (for `npx`),
[lychee](https://lychee.cli.rs/), and `jq`.

## Create a project

```bash
copier copy --trust git@github.com:xandronak/agent-docs-template.git <directory>
```

Copier asks for the project name, a one-sentence description, the GitHub repository, the CI
runner (GitHub-hosted, or a self-hosted Linux runner), and whether pull requests get the Claude
review. `--trust` lets the template write its ownership manifest and the decision index after
copying. Then commit, push, and follow the
message Copier prints.

## Update a project

In the project, the `update-template` skill does it, following the project's
`docs/contributing.md`, section 5: a branch from a clean `main`, then

```bash
copier update --trust --defaults
```

then conflict resolution by file ownership, the checks, and a pull request.

## Versions

Releases are Git tags `vMAJOR.MINOR.PATCH`, described in [`CHANGELOG.md`](CHANGELOG.md).
How versions are chosen and released: [`docs/maintaining.md`](docs/maintaining.md).
