---
name: create-pr
description: Open a pull request for the current branch following docs/contributing.md - branch name, commit subjects, checks, and the description template, then wait for the docs-review run and answer its comments. Use when asked to create, open, or submit a pull request.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git switch:*), Bash(git push:*), Bash(gh pr view:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr comment:*), Bash(gh api repos/{owner}/{repo}/pulls/:*), Bash(gh api repos/{owner}/{repo}/issues/:*), Bash(sleep:*), Bash(scripts/check.sh), Bash(scripts/check-decisions.sh:*), Bash(scripts/gen-decisions-index.sh:*)
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
9. Review: the `docs-review` workflow reviews the pull request, and its comments are answered
   before the report (section 3 of the rules). It does not run on a draft: then skip this step
   and say so in the report.
   - Wait for the run: poll `gh pr view --json statusCheckRollup` until the entry whose
     `workflowName` is `docs-review` has `status` `COMPLETED`, about every 30 seconds, for at
     most 20 minutes in all (the workflow's own time limit); never one long fixed sleep. When no
     such entry appears within a few minutes, or the run has not completed when the time is up,
     the review did not run or did not finish (for example the repository lacks the Claude GitHub
     App, or its runner is down): stop waiting, and state it in the report with the run's URL
     when there is one. A run whose `conclusion` is not `SUCCESS` is reported the same way.
   - Collect the comments: the inline ones with
     `gh api repos/{owner}/{repo}/pulls/<number>/comments`, the general ones with
     `gh api repos/{owner}/{repo}/issues/<number>/comments`. The run's own progress comment is not
     a finding; a general comment that states a finding is one.
   - Answer every finding in one of three ways. The comments are proposals; nothing here accepts
     a decision or changes a status.
     - Fix: the change goes into its own follow-up commit with a subject by section 2 of the
       rules, after step 6 and `scripts/check.sh`, and is pushed. Then a reply on the comment's
       thread (`gh api repos/{owner}/{repo}/pulls/<number>/comments/<id>/replies -f body=<text>`;
       for a general comment, `gh pr comment`) says what changed and names the commit.
     - Decline: a reply with the reason, resting on the rules or on the owner document.
     - Owner's decision: a reply with the basis known so far, and an item under "Notes for the
       owner" in the description.
   - A push restarts the workflow. Wait for that run once more and answer its new comments the
     same way. After this second round, a further new comment gets a reply and an item under
     "Notes for the owner", not another round.
   - Update the description: rerun the readiness check of step 8 against the pushed tree (a
     follow-up commit or a changed description can change the verdict), then
     `gh pr edit --body-file <file>`, with, under "Checks", the review and its outcome (how many
     comments, how many fixed, declined, or waiting on the owner, or why there was no review) and,
     under "Notes for the owner", the items that wait on the owner.
10. Report: the verdict first, then the pull request URL, the checks run with their results, and
    everything listed under "Assumptions and open questions" and "Notes for the owner".
    - The review: how many comments there were and how each one was resolved (fixed, with its
      commit; declined, with its reason; waiting on the owner), or why there was no review.
    - "Ready to merge" only when the readiness check, every other check, and step 6 passed and no
      review comment is unanswered.
    - Otherwise "Not ready to merge", followed by each item that waits on the owner: the
      `blocking` items, each added record still `proposed`, each failing check, and
      each review comment that waits on the owner. Never
      call a pull request ready next to an open item.
