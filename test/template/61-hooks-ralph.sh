# The Ralph cap of stop-check-docs.sh, then two commands the protect hook allows. Needs $a from
# 10-variant-a.sh and hook from 60-hooks-guard.sh.
# The Ralph cap: a failing Stop hook blocks until RALPH_MAX_ITERATIONS failing stops, then lets the
# agent stop with the cap message, and a passing check resets the count.
gitc "$a" switch -q -c ralph
printf '#Bad heading\n' > "$a/docs/bad.md" && sed -i.bak 's/^RALPH_MAX_ITERATIONS=.*/RALPH_MAX_ITERATIONS=2/' "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
gitc "$a" add -A && gitc "$a" commit -q -m bad
stop() { (cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-check-docs.sh > "$work/stop.log" 2>&1); }
stop; [ $? -eq 2 ] || fail "ralph cap: the first failing stop does not block"
stop; [ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "ralph cap: the stop at the cap still blocks"; }
stop; [ $? -eq 2 ] || fail "ralph cap: the count does not restart after the cap"
gitc "$a" switch -q main && gitc "$a" branch -q -D ralph && rm -f "$(git -C "$a" rev-parse --git-dir)"/ralph-stops-*
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"gh pr view 3 --json state"}}'
