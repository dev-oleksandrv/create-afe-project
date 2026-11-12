# session-start.sh: the state at session start. Needs $a from 10-variant-a.sh.
# The state at session start: at most ten lines of local facts, nothing outside a repository.
(cd "$a" && "$work/sj" 's.hooks.SessionStart[0].hooks[0].command.endsWith("/session-start.sh")') ||
  fail "settings: the SessionStart hook is not registered"
state() { (cd "${1:-$a}" && printf '{}' | CLAUDE_PROJECT_DIR="${1:-$a}" "$a/.claude/hooks/session-start.sh" > "$work/state.log" 2>&1); }
start=$(git -C "$a" rev-parse HEAD)
state; [ $? -eq 0 ] && grep -q "^- branch main; base main at [0-9a-f]*, 0 commits ahead$" "$work/state.log" &&
  grep -qx -- "- uncommitted files: 0; untracked files: 0" "$work/state.log" || { cat "$work/state.log"; fail "session-start: wrong state of a clean main"; }
mkdir -p "$work/norepo" && rm -f "$work/state.log"
state "$work/norepo"; [ $? -eq 0 ] && [ -f "$work/state.log" ] && [ ! -s "$work/state.log" ] || { cat "$work/state.log"; fail "session-start: prints or fails outside a repository"; }
gitc "$a" switch -q -c statebr && echo a > "$a/src.txt" && gitc "$a" add src.txt && gitc "$a" commit -q -m a
gitc "$a" switch -q -c c2 && echo b > "$a/src.txt" && gitc "$a" commit -q -am b
gitc "$a" switch -q statebr && echo c > "$a/src.txt" && gitc "$a" commit -q -am c
gitc "$a" merge -q c2 > /dev/null 2>&1
state; grep -qx -- "- unresolved merge conflicts in 1 files: resolve them first (git status lists them)" "$work/state.log" ||
  { cat "$work/state.log"; fail "session-start: no line for the merge conflict"; }
gitc "$a" merge --abort
# Seven plans: one past its review-by, one without it, five ahead; the output stays within 10 lines.
mkdir -p "$a/docs/plans" && printf -- '---\nreview-by: 2026-01-01\n---\n' > "$a/docs/plans/old.md"
printf -- '---\nstatus: active\n---\n' > "$a/docs/plans/bare.md"
for i in 1 2 3 4 5; do printf -- '---\nreview-by: 2999-01-0%s\n---\n' "$i" > "$a/docs/plans/p$i.md"; done
echo x >> "$a/README.md"
state; [ $? -eq 0 ] && [ "$(wc -l < "$work/state.log")" -le 10 ] &&
  grep -q "^- branch statebr; base main at [0-9a-f]*, 2 commits ahead$" "$work/state.log" &&
  grep -qx -- "- uncommitted files: 1; untracked files: 7" "$work/state.log" &&
  grep -qx -- "- plan docs/plans/bare.md: no review-by date" "$work/state.log" &&
  grep -qx -- "- plan docs/plans/old.md: review-by 2026-01-01 is past; update or delete it (docs/documentation-rules.md, section 5)" "$work/state.log" &&
  grep -qx -- "- plan docs/plans/p1.md: review-by 2999-01-01" "$work/state.log" &&
  grep -qx -- "- and 2 more plans in docs/plans/" "$work/state.log" || { cat "$work/state.log"; fail "session-start: wrong state of a branch with changes and plans"; }
# Past plans come first, so one that sorts last is not hidden behind five ahead; review-by on the
# day itself is not past; past plans beyond the five shown are counted; outside a repository only
# the plans are shown. SESSION_START_TODAY stands in for the clock.
pl="$work/plansonly" && mkdir -p "$pl/docs/plans"
for i in 1 2 3 4 5 6; do printf -- '---\nreview-by: 2030-01-0%s\n---\n' "$i" > "$pl/docs/plans/a$i.md"; done
printf -- '---\nreview-by: 2029-12-31\n---\n' > "$pl/docs/plans/z.md"
(cd "$pl" && printf '{}' | CLAUDE_PROJECT_DIR="$pl" SESSION_START_TODAY=2030-01-01 "$a/.claude/hooks/session-start.sh" > "$work/state.log" 2>&1)
grep -qx -- "- plan docs/plans/z.md: review-by 2029-12-31 is past; update or delete it (docs/documentation-rules.md, section 5)" "$work/state.log" &&
  grep -qx -- "- plan docs/plans/a1.md: review-by 2030-01-01" "$work/state.log" && grep -qx -- "- and 2 more plans in docs/plans/" "$work/state.log" &&
  ! grep -q -- "- branch\|uncommitted" "$work/state.log" ||
  { cat "$work/state.log"; fail "session-start: a past plan is hidden, the day itself counts as past, or the state outside a repository is wrong"; }
for i in 1 2 3 4 5 6 7; do printf -- '---\nreview-by: 2020-01-0%s\n---\n' "$i" > "$pl/docs/plans/old$i.md"; done
(cd "$pl" && printf '{}' | CLAUDE_PROJECT_DIR="$pl" SESSION_START_TODAY=2030-01-01 "$a/.claude/hooks/session-start.sh" > "$work/state.log" 2>&1)
[ "$(wc -l < "$work/state.log")" -le 10 ] && grep -qx -- "- and 9 more plans in docs/plans/, 3 of them past their review-by" "$work/state.log" ||
  { cat "$work/state.log"; fail "session-start: the past plans beyond the five shown are not counted"; }
gitc "$a" checkout -q -- . && gitc "$a" clean -q -fd && gitc "$a" switch -q main && git -C "$a" reset -q --hard "$start" &&
  gitc "$a" branch -q -D statebr c2
