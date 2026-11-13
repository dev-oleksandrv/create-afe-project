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
# A branch with changes: the commits ahead and the counts; a plan file is not listed.
mkdir -p "$a/docs/plans" && printf -- '---\nreview-by: 2026-01-01\n---\n' > "$a/docs/plans/old.md"
echo x >> "$a/README.md"
state; [ $? -eq 0 ] && [ "$(wc -l < "$work/state.log")" -le 10 ] &&
  grep -q "^- branch statebr; base main at [0-9a-f]*, 2 commits ahead$" "$work/state.log" &&
  grep -qx -- "- uncommitted files: 1; untracked files: 1" "$work/state.log" &&
  ! grep -q 'plan' "$work/state.log" || { cat "$work/state.log"; fail "session-start: wrong state of a branch with changes"; }
# The state is that of the repository that holds the input's cwd: a second worktree here.
swt="$work/state-wt"
gitc "$a" worktree add -q -b statewt "$swt" main
(cd "$a" && printf '{"cwd":"%s"}' "$swt" | CLAUDE_PROJECT_DIR="$a" "$a/.claude/hooks/session-start.sh" > "$work/state.log" 2>&1)
grep -q "^- branch statewt; base main at [0-9a-f]*, 0 commits ahead$" "$work/state.log" &&
  grep -qx -- "- uncommitted files: 0; untracked files: 0" "$work/state.log" ||
  { cat "$work/state.log"; fail "session-start: the state is not that of the worktree that the input's cwd names"; }
git -C "$a" worktree remove --force "$swt" && gitc "$a" branch -q -D statewt
gitc "$a" checkout -q -- . && gitc "$a" clean -q -fd && gitc "$a" switch -q main && git -C "$a" reset -q --hard "$start" &&
  gitc "$a" branch -q -D statebr c2
