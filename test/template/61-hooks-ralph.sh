# The Ralph cap of stop-dispatch.sh, then two commands the guard hook allows. Needs $a from
# 10-variant-a.sh and hook from 60-hooks-guard.sh; defines stop, which the later hook files use.
# The Ralph cap: a failing stop blocks until RALPH_MAX_ITERATIONS (2 by default) failing stops, then
# lets the agent stop with the cap message, and the count restarts. One count per session and
# worktree, in the worktree's own git directory.
stop() { # JSON input (default: session t), directory the hook runs in (default: variant A)
  local in=${1:-}
  [ -n "$in" ] || in='{"session_id":"t"}'
  (cd "${2:-$a}" && printf '%s' "$in" | CLAUDE_PROJECT_DIR="$a" "$a/.claude/hooks/stop-dispatch.sh" > "$work/stop.log" 2>&1)
}
gd=$(git -C "$a" rev-parse --absolute-git-dir)
grep -qx 'RALPH_MAX_ITERATIONS=2' "$a/.claude/harness.conf" || fail "harness.conf: RALPH_MAX_ITERATIONS is not 2 by default"
grep -qx 'REVIEW_MAX_ROUNDS=2' "$a/.claude/harness.conf" || fail "harness.conf: REVIEW_MAX_ROUNDS is not 2 by default"
gitc "$a" switch -q -c ralph
printf '#Bad heading\n' > "$a/docs/bad.md"
gitc "$a" add -A && gitc "$a" commit -q -m bad
stop; [ $? -eq 2 ] && [ -f "$gd/afe-ralph-t" ] || { cat "$work/stop.log"; fail "ralph cap: the first failing stop does not block or keeps no count in the git directory"; }
stop '{"session_id":"other"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: another session shares the count"; }
stop; [ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "ralph cap: the stop at the cap still blocks"; }
[ ! -e "$gd/afe-ralph-t" ] || fail "ralph cap: the count is not reset at the cap"
stop; [ $? -eq 2 ] || fail "ralph cap: the count does not restart after the cap"
gitc "$a" switch -q main && gitc "$a" branch -q -D ralph && rm -f "$gd"/afe-ralph-*
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"gh pr view 3 --json state"}}'
