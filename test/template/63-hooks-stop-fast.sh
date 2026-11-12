# stop-check-fast.sh, and every Stop hook during a merge conflict. Needs $a from 10-variant-a.sh.
# The fast check at a Stop: CHECK_FAST runs only when a file other than Markdown differs from the
# base, never when empty or the default scripts/check-docs.sh, blocks on a failure, and lets the
# agent stop during a merge conflict.
(cd "$a" && "$work/sj" 's.hooks.Stop[0].hooks.filter(h => h.command.endsWith("/stop-check-fast.sh")).length === 1') ||
  fail "settings: the fast Stop hook is not registered once"
fast() { (cd "$a" && printf '{"session_id":"fast"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-check-fast.sh > "$work/fast.log" 2>&1); }
start=$(git -C "$a" rev-parse HEAD)
echo x > "$a/src.txt" && cp "$a/scripts/check-docs.sh" "$work/check-docs.keep" &&
  printf '#!/usr/bin/env bash\necho check-docs ran; exit 1\n' > "$a/scripts/check-docs.sh"
fast; [ $? -eq 0 ] && [ ! -s "$work/fast.log" ] || { cat "$work/fast.log"; fail "stop-check-fast: the default CHECK_FAST runs"; }
cp "$a/scripts/env.sh" "$work/env.keep" && printf '#!/usr/bin/env bash\ntouch "%s/env.ran"; exit 1\n' "$work" > "$a/scripts/env.sh" &&
  sed -i.bak "s#^CHECK_FAST=.*#CHECK_FAST=#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
fast; [ $? -eq 0 ] && [ ! -e "$work/env.ran" ] && [ ! -s "$work/fast.log" ] || { cat "$work/fast.log"; fail "stop-check-fast: an empty CHECK_FAST runs"; }
cp "$work/env.keep" "$a/scripts/env.sh" && git -C "$a" checkout -q -- .claude/harness.conf
cp "$work/check-docs.keep" "$a/scripts/check-docs.sh" && rm "$a/src.txt"
sed -i.bak "s#^CHECK_FAST=.*#CHECK_FAST=echo fast-ran; test ! -e $work/fail.flag#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
gitc "$a" commit -q -am "fast check" && touch "$work/fail.flag"
fast; [ $? -eq 0 ] && [ ! -s "$work/fast.log" ] || { cat "$work/fast.log"; fail "stop-check-fast: runs without a change"; }
mkdir -p "$a/docs/plans" && printf -- '---\nstatus: active\nreview-by: 2999-12-31\n---\n\n# X\n' > "$a/docs/plans/x.md"
fast; [ $? -eq 0 ] && [ ! -s "$work/fast.log" ] || { cat "$work/fast.log"; fail "stop-check-fast: runs for a Markdown-only change"; }
echo x > "$a/src.txt"
fast; [ $? -eq 2 ] && grep -q fast-ran "$work/fast.log" || { cat "$work/fast.log"; fail "stop-check-fast: an untracked file and a failing CHECK_FAST do not block"; }
rm "$work/fail.flag"
fast; [ $? -eq 0 ] && [ ! -s "$work/fast.log" ] || { cat "$work/fast.log"; fail "stop-check-fast: a passing CHECK_FAST blocks or prints"; }
gitc "$a" switch -q -c fastbr && gitc "$a" add src.txt && gitc "$a" commit -q -m src && touch "$work/fail.flag"
fast; [ $? -eq 2 ] || { cat "$work/fast.log"; fail "stop-check-fast: a committed change and a failing CHECK_FAST do not block"; }
gitc "$a" switch -q -c c2 && echo b > "$a/src.txt" && gitc "$a" commit -q -am b
gitc "$a" switch -q fastbr && echo c > "$a/src.txt" && gitc "$a" commit -q -am c
gitc "$a" merge -q c2 > /dev/null 2>&1
fast; [ $? -eq 0 ] && grep -q "Unresolved merge conflicts" "$work/fast.log" || { cat "$work/fast.log"; fail "stop-check-fast: blocks during a merge conflict"; }
# Every Stop hook lets the agent stop during the conflict and points to where the conflicts are
# listed, not to a procedure that the documents do not have.
for h in docs decisions template fast; do
  (cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" ".claude/hooks/stop-check-$h.sh" > "$work/conflict.log" 2>&1)
  [ $? -eq 0 ] && grep -qxF "Unresolved merge conflicts: checks resume once they are resolved (git status lists them)." "$work/conflict.log" ||
    { cat "$work/conflict.log"; fail "stop-check-$h: blocks or gives no pointer during a merge conflict"; }
done
! grep -n -i -E 'conflict.*(template update|contributing\.md, section 5)' "$a"/.claude/hooks/* > "$work/conflict.log" ||
  { cat "$work/conflict.log"; fail "hooks: a merge conflict is tied to a template update or to contributing.md, section 5"; }
gitc "$a" merge --abort && rm -f "$work/fail.flag" "$a/docs/plans/x.md"
gitc "$a" switch -q main && git -C "$a" reset -q --hard "$start" && gitc "$a" branch -q -D fastbr c2 &&
  rm -f "$(git -C "$a" rev-parse --absolute-git-dir)"/ralph-stops-*
