# The Ralph cap of stop-dispatch.sh, then two commands the guard hook allows. Needs $a from
# 10-variant-a.sh and hook from 60-hooks-guard.sh; defines stop, which the later hook files use.
# The Ralph cap: a failing stop blocks until RALPH_MAX_ITERATIONS (2 by default) failing stops, then
# lets the agent stop with the cap message, and the count restarts. One count per session, agent,
# and worktree, in the worktree's own git directory.
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
(cd "$a" && printf '{"session_id":"t"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-dispatch.sh > "$work/stop.out" 2> "$work/stop.log")
[ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "ralph cap: the stop at the cap still blocks"; }
# At the cap stdout is one JSON object with a systemMessage, so the user sees it too.
node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).systemMessage;
  process.exit(typeof m === "string" && !m.includes("\n") && /^Stop checks still fail after 2 attempts: .*scripts\/check-docs\.sh.*; cap reached$/.test(m) ? 0 : 1)' "$work/stop.out" ||
  { cat "$work/stop.out"; fail "ralph cap: stdout at the cap is not JSON with a one-line systemMessage naming the failing part"; }
[ ! -e "$gd/afe-ralph-t" ] || fail "ralph cap: the count is not reset at the cap"
stop; [ $? -eq 2 ] || fail "ralph cap: the count does not restart after the cap"
rm -f "$gd"/afe-ralph-*
# Sub-agents carry the parent's session_id: each agent_id counts apart from the others and from
# the main agent of the session.
stop '{"session_id":"s","agent_id":"one"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: the first failing stop of sub-agent one does not block"; }
stop '{"session_id":"s","agent_id":"two"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: two sub-agents of one session share the count"; }
stop '{"session_id":"s"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: the main agent shares the count of its sub-agents"; }
stop '{"session_id":"s","agent_id":"one"}'; [ $? -eq 0 ] || { cat "$work/stop.log"; fail "ralph cap: sub-agent one does not reach its own cap"; }
gitc "$a" switch -q main && gitc "$a" branch -q -D ralph && rm -f "$gd"/afe-ralph-*
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"gh pr view 3 --json state"}}'
