#!/usr/bin/env bash
# Stop and SubagentStop hook: Claude Code may not finish a turn, or a sub-agent its task, while a
# check of what changed fails. It resolves the generated project from the input's cwd
# (scripts/lib/root.sh), so a sub-agent in another git worktree is checked in that worktree. On a
# tree whose green stamp (scripts/lib/stamp.sh) matches the last passing run of this hook or of
# scripts/check.sh, it runs nothing; so a second run for the same stop, from Stop and SubagentStop both, is a no-op. Else it
# runs, for the paths that differ from the base of the change (scripts/lib/git-base.sh), committed
# or not, untracked included, each part that has input, every part even when an earlier one fails:
# - a Markdown file changed: scripts/check-docs.sh with the changed Markdown files (all files when
#   one was deleted); a missing tool (exit 3) is reported without blocking;
# - a path under docs/decisions/ changed: scripts/check-decisions.sh, the integrity checks;
# - a path other than Markdown changed, and CHECK_FAST of .claude/harness.conf is set and is not
#   scripts/check-docs.sh: scripts/env.sh fast;
# - always: each .claude/hooks/project/stop/*.sh in name order, with the hook input on stdin; exit 2
#   or a hook that is not executable fails, another exit code is reported without blocking.
# All parts pass: it stores the fast stamp, resets the Ralph count, and prints nothing. A part
# fails: one message on stderr names each failing part with at most the last 40 lines of its
# output, and exit 2 sends the agent back, up to RALPH_MAX_ITERATIONS failing stops per session,
# agent, and worktree (scripts/lib/harness-conf.sh); at the cap a systemMessage on stdout tells the
# user. During an unresolved merge conflict it lets the agent stop.
# Not in GitHub Actions: claude-code-action restores .claude/ from the base branch there, but the
# scripts this hook and the project's Stop hooks run or source stay at the pull request's head,
# next to the review job's credentials.
[ -z "${GITHUB_ACTIONS:-}" ] || exit 0
set -uo pipefail
shopt -s nullglob
lib=$(cd "$(dirname "$0")/../../scripts/lib" 2>/dev/null && pwd) || exit 0
# shellcheck source=scripts/lib/root.sh
. "$lib/root.sh" 2>/dev/null || exit 0
input=$(cat)
session= cwd= agent=
{ IFS= read -r -d '' session; IFS= read -r -d '' cwd; IFS= read -r -d '' agent; } < <(printf '%s' "$input" |
  node "$lib/json.mjs" fields session_id cwd agent_id 2>/dev/null)
# The key of the Ralph count: a sub-agent carries its parent's session_id, so its agent_id joins it.
key=$session${agent:+.$agent}
root=$(resolve_root "$cwd") || exit 0
cd "$root" || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null && . scripts/lib/stamp.sh 2>/dev/null &&
  . scripts/lib/git-base.sh 2>/dev/null || exit 0

# During an unresolved merge conflict the checks cannot pass yet; let the
# agent stop and ask instead of looping.
if [ -n "$(git ls-files -u 2>/dev/null)" ]; then
  echo "Unresolved merge conflicts: checks resume once they are resolved (git status lists them)." >&2
  exit 0
fi

stamp=$(tree_stamp)
stamp_matches fast "$stamp" && exit 0

base=$(resolve_base 2>/dev/null) || base=HEAD
md=() md_gone= decisions= other=
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    *.md) if [ -f "$f" ]; then md+=("$f"); else md_gone=1; fi ;;
    *) other=1 ;;
  esac
  case "$f" in docs/decisions/*) decisions=1 ;; esac
done < <( { git -c core.quotePath=false diff --name-only --no-renames "$base" --
  git -c core.quotePath=false ls-files --others --exclude-standard; } 2>/dev/null | sort -u)

failures= warnings= failed=
# part <name> <how> <command>...: runs the command from the root, stdin from $part_input; <how> is
# docs (exit 3 warns), project (exit 2 fails, another non-zero exit warns), or plain (non-zero fails).
part_input=
part() {
  local name=$1 how=$2 out code
  shift 2
  out=$(printf '%s' "$part_input" | "$@" 2>&1)
  code=$?
  [ "$code" -eq 0 ] && return 0
  out=$(printf '%s\n' "$out" | tail -n 40)
  if { [ "$how" = docs ] && [ "$code" -eq 3 ]; } || { [ "$how" = project ] && [ "$code" -ne 2 ]; }; then
    warnings+=$(printf '\n== %s could not run or exited %s, not blocking:\n%s' "$name" "$code" "$out")
  else
    failures+=$(printf '\n== %s failed (exit %s):\n%s' "$name" "$code" "$out")
    failed=${failed:+$failed, }$name
  fi
}

if [ -n "$md_gone" ]; then
  part "scripts/check-docs.sh" docs scripts/check-docs.sh
elif [ "${#md[@]}" -gt 0 ]; then
  part "scripts/check-docs.sh" docs scripts/check-docs.sh "${md[@]}"
fi
[ -z "$decisions" ] || part "scripts/check-decisions.sh" plain scripts/check-decisions.sh
if [ -n "$other" ]; then
  case "$(conf_get CHECK_FAST)" in
    ''|scripts/check-docs.sh) ;;
    *) part "the fast check, scripts/env.sh fast (CHECK_FAST in .claude/harness.conf)" plain scripts/env.sh fast ;;
  esac
fi
part_input=$input
for h in .claude/hooks/project/stop/*.sh; do
  if [ -x "$h" ]; then
    part "project Stop hook $h" project "$h"
  else
    failures+=$(printf '\n== project Stop hook %s is not executable; run chmod +x and commit it.' "$h")
    failed=${failed:+$failed, }project Stop hook $h
  fi
done

if [ -n "$failures" ]; then
  ralph_block "$key" "$(printf 'Stop checks failed; fix them before finishing:%s%s' "$failures" "$warnings")" "$failed"
fi
ralph_pass "$key"
if [ -n "$warnings" ]; then
  printf 'Stop checks: some parts could not run:%s\n' "$warnings" >&2
  exit 1
fi
stamp_write fast "$stamp"
exit 0
