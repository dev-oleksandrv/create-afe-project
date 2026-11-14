#!/usr/bin/env bash
# Stop and SubagentStop hook: Claude Code may not finish a turn, or a sub-agent its task, while a
# check of what changed fails. It resolves the generated project from the input's cwd
# (scripts/lib/root.sh), so a sub-agent in another git worktree is checked in that worktree. A
# sub-agent's stop (SubagentStop, or an input with agent_id) in the main session's tree, the root
# of CLAUDE_PROJECT_DIR, runs nothing and prints nothing: the main agent's Stop checks that tree,
# and a sub-agent must not be sent back for what it did not change.
# The green stamp (scripts/lib/stamp.sh) has two kinds, docs (Markdown) and code (every other
# path); a kind whose stamp matches the last passing run of this hook or of scripts/check.sh runs
# nothing, and with both matching the hook runs nothing at all, so a second run for the same stop,
# from Stop and SubagentStop both, is a no-op. Else it runs, for the paths that differ from the base
# of the change (scripts/lib/git-base.sh), committed or not, untracked included, each part that has
# input, every part even when an earlier one fails:
# - a Markdown file changed and the docs stamp does not match: scripts/check-docs.sh with the
#   changed Markdown files (all files when one was deleted), a missing tool (exit 3) is reported
#   without blocking; and, when a path under docs/decisions/ changed, scripts/check-decisions.sh,
#   the integrity checks;
# - a path other than Markdown changed, the code stamp does not match, and CHECK_FAST of
#   .claude/harness.conf is set and is not scripts/check-docs.sh: scripts/env.sh fast;
# - always: each .claude/hooks/project/stop/*.sh in name order, with the hook input on stdin; exit 2
#   or a hook that is not executable fails, another exit code is reported without blocking.
# It stores the fast stamp of each kind whose parts and the project's Stop hooks all passed, even
# when the other kind failed. All parts pass: it resets the Ralph count and prints nothing. A part
# fails: one message on stderr names each failing part with at most the last 40 lines of its
# output (scripts/check-docs.sh: a summary instead, see docs_brief; its missing tool report: the
# first 10 lines), and exit 2 sends the agent back, up to RALPH_MAX_ITERATIONS failing stops per session,
# agent, and worktree (scripts/lib/harness-conf.sh); at the cap a systemMessage on stdout tells the
# user, and later stops of the same key on the same tree (both stamps) exit 0 at once, silently,
# until the tree changes. During an unresolved merge conflict it lets the agent stop.
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
session= cwd= agent= event=
{ IFS= read -r -d '' session; IFS= read -r -d '' cwd; IFS= read -r -d '' agent; IFS= read -r -d '' event; } < <(
  printf '%s' "$input" | node "$lib/json.mjs" fields session_id cwd agent_id hook_event_name 2>/dev/null)
# The key of the Ralph count: a sub-agent carries its parent's session_id, so its agent_id joins it.
key=$session${agent:+.$agent}
root=$(resolve_root "$cwd") || exit 0
# A sub-agent in the main session's tree: the main agent's Stop checks it.
if [ "$event" = SubagentStop ] || [ -n "$agent" ]; then
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ] &&
    [ "$(resolve_root "$CLAUDE_PROJECT_DIR")" = "$root" ]; then
    exit 0
  fi
fi
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

{ IFS= read -r code_stamp; IFS= read -r docs_stamp; } < <(tree_stamps)
code_green= docs_green=
stamp_matches fast code "$code_stamp" && code_green=1
stamp_matches fast docs "$docs_stamp" && docs_green=1
[ -n "$code_green" ] && [ -n "$docs_green" ] && exit 0
# The cap was reached on this tree for this key: let the agent stop, as it did then.
ralph_capped "$key" "$code_stamp $docs_stamp" && exit 0

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
# The kinds whose parts did not all pass: code, docs, or both (the project's Stop hooks).
bad=
# part <name> <kind> <how> <command>...: runs the command from the root, stdin from $part_input;
# <kind> is code, docs, or both; <how> is docs (exit 3 warns, a failure gets docs_brief), project
# (exit 2 fails, another non-zero exit warns), or plain (non-zero fails). Either way the kind does
# not get its stamp.
part_input=
# docs_brief <output>: keeps a documentation failure from flooding the chat: the first 10 lines of
# the output, then how many lines remain.
docs_brief() {
  printf '%s\n' "$1" | awk '
    { total++; if (total <= 10) print }
    END { if (total > 10) print "... " (total - 10) " more lines" }'
}
part() {
  local name=$1 kind=$2 how=$3 out code cmd
  shift 3
  out=$(printf '%s' "$part_input" | "$@" 2>&1)
  code=$?
  [ "$code" -eq 0 ] && return 0
  bad+=" $kind"
  if [ "$how" = docs ] && [ "$code" -eq 3 ]; then
    out=$(printf '%s\n' "$out" | head -n 10)
  elif [ "$how" = docs ]; then
    cmd=$(printf '%q ' "$@")
    out=$(docs_brief "$out"; printf 'Full output: %s' "${cmd% }")
  else
    out=$(printf '%s\n' "$out" | tail -n 40)
  fi
  if { [ "$how" = docs ] && [ "$code" -eq 3 ]; } || { [ "$how" = project ] && [ "$code" -ne 2 ]; }; then
    warnings+=$(printf '\n== %s could not run or exited %s, not blocking:\n%s' "$name" "$code" "$out")
  else
    failures+=$(printf '\n== %s failed (exit %s):\n%s' "$name" "$code" "$out")
    failed=${failed:+$failed, }$name
  fi
}

if [ -z "$docs_green" ]; then
  if [ -n "$md_gone" ]; then
    part "scripts/check-docs.sh" docs docs scripts/check-docs.sh
  elif [ "${#md[@]}" -gt 0 ]; then
    part "scripts/check-docs.sh" docs docs scripts/check-docs.sh "${md[@]}"
  fi
  if [ -n "$decisions" ] && { [ -n "$md_gone" ] || [ "${#md[@]}" -gt 0 ]; }; then
    part "scripts/check-decisions.sh" docs plain scripts/check-decisions.sh
  fi
fi
if [ -n "$other" ] && [ -z "$code_green" ]; then
  case "$(conf_get CHECK_FAST)" in
    ''|scripts/check-docs.sh) ;;
    *) part "the fast check, scripts/env.sh fast (CHECK_FAST in .claude/harness.conf)" code plain scripts/env.sh fast ;;
  esac
fi
part_input=$input
for h in .claude/hooks/project/stop/*.sh; do
  if [ -x "$h" ]; then
    part "project Stop hook $h" both project "$h"
  else
    bad+=" both"
    failures+=$(printf '\n== project Stop hook %s is not executable; run chmod +x and commit it.' "$h")
    failed=${failed:+$failed, }project Stop hook $h
  fi
done

case "$bad" in *code*|*both*) ;; *) stamp_write fast code "$code_stamp" ;; esac
case "$bad" in *docs*|*both*) ;; *) stamp_write fast docs "$docs_stamp" ;; esac
if [ -n "$failures" ]; then
  ralph_block "$key" "$(printf 'Stop checks failed; fix them before finishing:%s%s' "$failures" "$warnings")" "$failed" \
    "$code_stamp $docs_stamp"
fi
ralph_pass "$key"
if [ -n "$warnings" ]; then
  printf 'Stop checks: some parts could not run:%s\n' "$warnings" >&2
  exit 1
fi
exit 0
