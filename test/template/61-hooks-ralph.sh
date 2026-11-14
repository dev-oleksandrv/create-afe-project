# The Ralph cap of stop-dispatch.sh, then two commands the guard hook allows. Needs $a from
# 10-variant-a.sh and hook from 60-hooks-guard.sh; defines stop, which the later hook files use.
# The Ralph cap: a failing stop blocks until RALPH_MAX_ITERATIONS (2 by default) failing stops, then
# lets the agent stop with the cap message; later stops of the same key on the same tree exit 0 at
# once, running nothing, until the tree changes; a green run clears that record. One count per
# session, agent, and worktree, in the worktree's own git directory.
stop() { # JSON input (default: session t), directory the hook runs in (default: variant A);
  # CLAUDE_PROJECT_DIR is $pd when set, even empty, else variant A
  local in=${1:-}
  [ -n "$in" ] || in='{"session_id":"t"}'
  (cd "${2:-$a}" && printf '%s' "$in" | CLAUDE_PROJECT_DIR="${pd-$a}" "$a/.claude/hooks/stop-dispatch.sh" > "$work/stop.log" 2>&1)
}
gd=$(git -C "$a" rev-parse --absolute-git-dir)
grep -qx 'RALPH_MAX_ITERATIONS=2' "$a/.claude/harness.conf" || fail "harness.conf: RALPH_MAX_ITERATIONS is not 2 by default"
grep -qx 'REVIEW_MAX_ROUNDS=2' "$a/.claude/harness.conf" || fail "harness.conf: REVIEW_MAX_ROUNDS is not 2 by default"
gitc "$a" switch -q -c ralph
printf '# Bad\n\nSee [x](nope.md).\n' > "$a/docs/bad.md"
# A failing fast check that counts its runs.
sed -i.bak "s#^CHECK_FAST=.*#CHECK_FAST=echo run >> $work/ralph.runs; exit 1#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
gitc "$a" add -A && gitc "$a" commit -q -m bad
runs() { cat "$work/ralph.runs" 2> /dev/null | wc -l | tr -d ' '; }
stop; [ $? -eq 2 ] && [ -f "$gd/afe-ralph-t" ] && [ "$(runs)" = 1 ] ||
  { cat "$work/stop.log"; fail "ralph cap: the first failing stop does not block, run the checks, or keep a count in the git directory"; }
stop '{"session_id":"other"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: another session shares the count"; }
(cd "$a" && printf '{"session_id":"t"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-dispatch.sh > "$work/stop.out" 2> "$work/stop.log")
[ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "ralph cap: the stop at the cap still blocks"; }
# At the cap stdout is one JSON object with a systemMessage, so the user sees it too.
node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).systemMessage;
  process.exit(typeof m === "string" && !m.includes("\n") && /^Stop checks still fail after 2 attempts: .*scripts\/check-docs\.sh.*; cap reached$/.test(m) ? 0 : 1)' "$work/stop.out" ||
  { cat "$work/stop.out"; fail "ralph cap: stdout at the cap is not JSON with a one-line systemMessage naming the failing part"; }
[ ! -e "$gd/afe-ralph-t" ] && [ -s "$gd/afe-ralph-t.cap" ] || fail "ralph cap: the count is not reset, or the tree is not recorded, at the cap"
# The same red tree after the cap: two more stops exit 0 at once, silently, running no check.
[ "$(runs)" = 3 ] || fail "ralph cap: expected 3 runs of the fast check before the cap record, got $(runs)"
for i in 1 2; do
  stop; [ $? -eq 0 ] && [ ! -s "$work/stop.log" ] && [ "$(runs)" = 3 ] ||
    { cat "$work/stop.log"; fail "ralph cap: stop $i after the cap on the same tree blocks, prints, or runs a check"; }
done
# A changed tree blocks again, with a fresh count.
echo x > "$a/src.txt"
stop; [ $? -eq 2 ] && [ "$(runs)" = 4 ] && [ "$(cat "$gd/afe-ralph-t")" = 1 ] ||
  { cat "$work/stop.log"; fail "ralph cap: a changed tree does not block again with a fresh count after the cap"; }
# Sub-agents carry the parent's session_id: each agent_id counts apart from the others and from
# the main agent of the session. Without CLAUDE_PROJECT_DIR a sub-agent is checked wherever it is.
pd= stop '{"session_id":"s","agent_id":"one"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: the first failing stop of sub-agent one does not block"; }
pd= stop '{"session_id":"s","agent_id":"two"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: two sub-agents of one session share the count"; }
stop '{"session_id":"s"}'; [ $? -eq 2 ] || { cat "$work/stop.log"; fail "ralph cap: the main agent shares the count of its sub-agents"; }
pd= stop '{"session_id":"s","agent_id":"one"}'; [ $? -eq 0 ] || { cat "$work/stop.log"; fail "ralph cap: sub-agent one does not reach its own cap"; }
# A green run clears the cap record.
stop; [ $? -eq 0 ] && [ -s "$gd/afe-ralph-t.cap" ] || { cat "$work/stop.log"; fail "ralph cap: the second stop on the changed tree does not reach the cap"; }
rm "$a/src.txt" && gitc "$a" switch -q main && rm -f "$gd"/afe-green-*
stop; [ $? -eq 0 ] && [ ! -e "$gd/afe-ralph-t.cap" ] || { cat "$work/stop.log"; fail "ralph cap: a green run does not clear the cap record"; }
gitc "$a" branch -q -D ralph && rm -f "$gd"/afe-ralph-* "$work/ralph.runs"
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"gh pr view 3 --json state"}}'
