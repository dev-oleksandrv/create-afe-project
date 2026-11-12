# stop-dispatch.sh: silent on a clean tree, one combined message for failing parts, the cap, no
# second run on an unchanged green tree, the worktree of the input's cwd, and the project around a
# nested repository without the harness. Needs $a from
# 10-variant-a.sh and stop from 61-hooks-ralph.sh.
echo "== the Stop dispatcher"
gd=$(git -C "$a" rev-parse --absolute-git-dir)
rm -f "$gd"/afe-green-* "$gd"/afe-ralph-*
start=$(git -C "$a" rev-parse HEAD)
stop; [ $? -eq 0 ] && [ ! -s "$work/stop.log" ] || { cat "$work/stop.log"; fail "stop-dispatch: prints or blocks on a clean tree"; }
# Two failing parts: one message names both, then the stop at the cap lets the agent stop.
gitc "$a" switch -q -c disp
sed -i.bak "s#^CHECK_FAST=.*#CHECK_FAST=echo fast-broke; exit 1#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
printf '#Bad heading\n' > "$a/docs/bad.md"
stop; [ $? -eq 2 ] && [ "$(grep -c '^Stop checks failed' "$work/stop.log")" -eq 1 ] &&
  grep -q '^== scripts/check-docs.sh failed' "$work/stop.log" && grep -q '^== the fast check.* failed' "$work/stop.log" &&
  grep -qx fast-broke "$work/stop.log" || { cat "$work/stop.log"; fail "stop-dispatch: two failing parts do not give one message that names both"; }
stop; [ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "stop-dispatch: blocks at the cap"; }
rm "$a/docs/bad.md"
# A green tree: the first stop runs the fast check, a second stop on the unchanged tree runs nothing,
# and a change runs it again.
sed -i.bak "s#^CHECK_FAST=.*#CHECK_FAST=touch $work/fast.marker#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
stop; [ $? -eq 0 ] && [ ! -s "$work/stop.log" ] && [ -e "$work/fast.marker" ] && [ -f "$gd/afe-green-fast" ] ||
  { cat "$work/stop.log"; fail "stop-dispatch: a passing fast check prints, blocks, does not run, or stores no stamp"; }
rm -f "$work/fast.marker"
stop; [ $? -eq 0 ] && [ ! -s "$work/stop.log" ] && [ ! -e "$work/fast.marker" ] || fail "stop-dispatch: runs a check again on an unchanged green tree"
echo x > "$a/src.txt"
stop; [ $? -eq 0 ] && [ -e "$work/fast.marker" ] || { cat "$work/stop.log"; fail "stop-dispatch: does not run the check again after a change"; }
# A full stamp of scripts/check.sh satisfies the dispatcher too.
rm -f "$work/fast.marker" "$gd/afe-green-fast" && echo y > "$a/src.txt" && (cd "$a" && . scripts/lib/stamp.sh && stamp_write full)
stop; [ $? -eq 0 ] && [ ! -e "$work/fast.marker" ] || fail "stop-dispatch: a matching full stamp does not satisfy it"
rm -f "$work/fast.marker" "$a/src.txt"
gitc "$a" checkout -q -- .claude/harness.conf && gitc "$a" switch -q main && gitc "$a" branch -q -D disp
# A stop whose cwd is a second worktree checks that worktree, not the session's project, and
# counts in that worktree's git directory.
dwt="$work/disp-wt"
gitc "$a" worktree add -q -b dispwt "$dwt" && printf '#Bad heading\n' > "$dwt/docs/bad.md"
dgd=$(git -C "$dwt" rev-parse --absolute-git-dir)
stop '{"session_id":"wt","cwd":"'"$dwt"'"}' "$work"
[ $? -eq 2 ] && grep -q '^== scripts/check-docs.sh failed' "$work/stop.log" && [ -f "$dgd/afe-ralph-wt" ] && [ ! -e "$gd/afe-ralph-wt" ] ||
  { cat "$work/stop.log"; fail "stop-dispatch: a cwd in a second worktree does not check that worktree, or counts elsewhere"; }
stop '{"session_id":"wt","cwd":"'"$a"'"}' "$work"
[ $? -eq 0 ] && [ ! -s "$work/stop.log" ] || { cat "$work/stop.log"; fail "stop-dispatch: a cwd in the main checkout checks the second worktree"; }
git -C "$a" worktree remove --force "$dwt" && gitc "$a" branch -q -D dispwt
# A cwd in a nested repository without the harness (a vendored clone) checks the project around
# it, not nothing.
mkdir -p "$a/vendor/dep" && git -C "$a/vendor/dep" init -q && printf '#Bad heading\n' > "$a/docs/bad.md"
stop '{"session_id":"nested","cwd":"'"$a"'/vendor/dep"}' "$a/vendor/dep"
[ $? -eq 2 ] && grep -q '^== scripts/check-docs.sh failed' "$work/stop.log" ||
  { cat "$work/stop.log"; fail "stop-dispatch: a cwd in a nested repository without the harness does not check the project"; }
rm -rf "$a/vendor" "$a/docs/bad.md"
git -C "$a" reset -q --hard "$start" && rm -f "$gd"/afe-green-* "$gd"/afe-ralph-*
