---
name: update-template
description: Update this repository to a newer version of the project template with copier, resolve conflicts by file ownership, run the checks, and open the pull request. Use when asked to update, sync, or upgrade the template.
allowed-tools: Read, Grep, Glob, Edit, Bash(git status:*), Bash(git switch:*), Bash(git fetch:*), Bash(git pull:*), Bash(git diff:*), Bash(git ls-remote:*), Bash(git clone:*), Bash(copier update:*), Bash(scripts/check.sh), Bash(scripts/gen-decisions-index.sh:*)
---

# Update the project template

Arguments: none for the latest release, or a template version such as `v1.2.0`.

The rules are in `docs/contributing.md`, section 5, and file ownership in
`docs/documentation-rules.md`, section 9. Read both first; this skill applies them.

## Procedure

1. State: `git status --porcelain` must be empty and the current branch `main`, up to date with
   `git pull --ff-only`. Otherwise stop and report.
2. Versions: read `_commit` and `_src_path` from `.copier-answers.yml`; list the template's tags
   with `git ls-remote --tags <_src_path>`. The target is the argument or the highest tag. When
   the target equals `_commit`, stop and report that the repository is up to date.
3. Branch: `git switch -c chore/template-update`. Read the template's changelog:
   `git clone --quiet --depth 1 --branch <target> <_src_path> <scratch directory>`, then its
   `CHANGELOG.md`; the scratch directory is outside the repository.
4. Update: `copier update --trust --defaults --vcs-ref=<target>`. The template rewrites its own
   files, then regenerates `.template/owned.sha256` and the decision index.
5. Conflicts: find every `<<<<<<<` marker and `*.rej` file and resolve each by the rules of
   `docs/contributing.md`, section 5, step 3 (template-owned, generated, seeded and project
   files). When you cannot tell, stop and list the conflict as a `blocking:` question.
6. Checks: run `scripts/check.sh`. A failure caused by the new template version is listed in the
   report with the template's changelog entry that explains it; do not edit a template-owned file
   to make it pass.
7. Commit and open the pull request with the `create-pr` skill, title
   `Template: update to <target>`. Under "Summary" list the changelog entries from the previous
   version to the target, and under "Notes for the owner" every conflict and how it was
   resolved.
8. Report: the previous and the new version, the pull request, the checks, and the conflicts.
