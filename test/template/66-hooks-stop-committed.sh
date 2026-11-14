# stop-dispatch.sh blocks a committed broken document on a feature branch. Needs $a from
# 10-variant-a.sh and stop from 61-hooks-ralph.sh.
gitc "$a" switch -q -c feature
printf '# Bad\n\n[missing](nowhere.md)\n' > "$a/docs/bad.md"
gitc "$a" add -A && gitc "$a" commit -q -m bad
stop '{"session_id":"committed"}'
[ $? -eq 2 ] && grep -q 'scripts/check-docs.sh failed' "$work/stop.log" || { cat "$work/stop.log"; fail "stop-dispatch lets a committed broken document through"; }
gitc "$a" switch -q main && gitc "$a" branch -q -D feature && rm -f "$(git -C "$a" rev-parse --absolute-git-dir)"/afe-ralph-*
