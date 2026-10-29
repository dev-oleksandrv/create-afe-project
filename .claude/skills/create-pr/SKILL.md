---
name: create-pr
description: Open a pull request for the current branch following docs/contributing.md - branch name, commit subjects, checks, and the description template. Use when asked to create, open, or submit a pull request.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git switch:*), Bash(git push:*), Bash(gh pr view:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(scripts/check.sh), Bash(scripts/check-decisions.sh:*), Bash(scripts/gen-decisions-index.sh:*)
---

# Create a pull request

Arguments: none, or free text that seeds the title and the summary.

The rules are in `docs/contributing.md`. Read it first; this skill applies it and does not
restate it. Nothing here changes a status, accepts a decision, or merges: the owner does that.

## Procedure

1. Establish the state: `git status --porcelain`, `git branch --show-current`,
   `git log --format='%h %s' main..HEAD`, `git rev-parse --abbrev-ref @{upstream}` (fails when
   the branch was never pushed), `gh pr view --json url,state,isDraft` (fails when no pull
   request exists for the branch).
   - A pull request already exists for the branch: do not open a second one. Push the new
     commits, update the description with `gh pr edit --body-file`, and say so.
   - On `main` with changes: first create a branch named by section 1 of the rules with
     `git switch -c <type>/<slug>`.
   - On `main` with no changes: stop and report that there is nothing to submit.
2. Branch name: it must match `<type>/<slug>` with the types of section 1 and a lowercase
   `-`-joined slug. A branch that does not match and was never pushed is renamed with
   `git branch -m <type>/<slug>`. A pushed one keeps its name and is listed under
   "Notes for the owner".
3. Uncommitted changes: stage the files by name, never everything at once, and commit them with
   a subject by section 2, one commit per logical change, a body when the subject is not enough,
   and the co-author trailer. Files the user did not ask to change stay uncommitted and are named
   in the report.
4. Commit subjects on the branch: each must be `<Scope>: <summary>` with a lowercase summary, no
   trailing period, at most 72 characters. Only the last commit, and only while it is not pushed,
   may be reworded with `git commit --amend`. Any other subject that does not conform is left as
   it is and listed under "Notes for the owner". History is never rewritten after a push.
5. Checks: when a file under `docs/decisions/` changed, regenerate the index with
   `scripts/gen-decisions-index.sh > docs/decisions/README.md` and commit it with the records.
   Then run `scripts/check.sh`. A failing check is fixed before the pull request
   is opened; when it cannot be fixed, the pull request is opened as a draft and the failure is
   quoted under "Checks".
6. Owner documents: for every changed file, find the owner document through `docs/README.md` and
   confirm it is updated in the same branch (`docs/documentation-rules.md`, section 5). A missing
   update is made now, in its own commit, or listed as an open question. After any such commit,
   run `scripts/check.sh` again, so that the checks describe the tree that is pushed.
7. Push: `git push -u origin <branch>`.
8. Description: write it to a file outside the repository (the session's scratch directory) in
   exactly the sections and order of section 3 of the rules, from `git diff main...HEAD`, the
   commit messages, and the conversation. Then run
   `gh pr create --base main --title "<Scope>: <summary>" --body-file <file>`, with `--draft`
   when step 5 said so. End the body with the attribution line that this session's instructions
   prescribe, when there is one.
   - Facts only: every bullet in Summary names a status; nothing is called implemented without a
     test; every protected file touched is listed under "Notes for the owner" together with the
     instruction that allowed the change.
   - Every item under "Assumptions and open questions" carries the label of section 3 of the
     rules: `blocking:` for a question about this pull request, `recorded:` with the owner
     document that holds the question, `assumption:`. A question the branch can still answer
     itself is resolved now, not listed.
   - Before `gh pr create` (or `gh pr edit`), run
     `scripts/check-decisions.sh --ready --base origin/main --pr-body <file>`. Its result is the
     readiness verdict.
     A failure here alone does not make the pull request a draft: it waits on the owner.
9. Report: the verdict first, then the pull request URL, the checks run with their results, and
   everything listed under "Assumptions and open questions" and "Notes for the owner".
   - "Ready to merge" only when the readiness check, every other check, and step 6 passed and no
     review comment is unanswered.
   - Otherwise "Not ready to merge", followed by each item that waits on the owner: the
     `blocking` items, each added record still `proposed`, each failing check. Never call a pull
     request ready next to an open item.
