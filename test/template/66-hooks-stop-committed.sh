# stop-check-docs.sh blocks a committed broken document on a feature branch. Needs $a from
# 10-variant-a.sh.
gitc "$a" switch -q -c feature
printf '#Bad heading\n\n[missing](nowhere.md)\n' > "$a/docs/bad.md"
gitc "$a" add -A && gitc "$a" commit -q -m bad
(cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-check-docs.sh > /dev/null 2>&1)
[ $? -eq 2 ] || fail "stop-check-docs lets a committed broken document through"
gitc "$a" switch -q main && gitc "$a" branch -q -D feature
