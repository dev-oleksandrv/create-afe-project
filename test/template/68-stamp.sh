# The green stamp (scripts/lib/stamp.sh) and scripts/check.sh: quiet output, --if-changed, and the
# full stamp, which GitHub Actions never reads or writes. Needs $a from 10-variant-a.sh.
echo "== the green stamp and scripts/check.sh"
st() { (cd "$a" && . scripts/lib/stamp.sh && "$@"); }
gd=$(git -C "$a" rev-parse --absolute-git-dir)
s0=$(st tree_stamp)
printf '%s' "$s0" | grep -qE '^[0-9a-f]{64}$' && [ "$(st tree_stamp)" = "$s0" ] || fail "stamp: tree_stamp is not a stable SHA-256 ($s0)"
echo x >> "$a/README.md"
s1=$(st tree_stamp); [ "$s1" != "$s0" ] || fail "stamp: unchanged when a tracked file changes"
gitc "$a" checkout -q -- README.md
[ "$(st tree_stamp)" = "$s0" ] || fail "stamp: differs after a tracked file is restored"
echo a > "$a/new.txt"
s2=$(st tree_stamp); [ "$s2" != "$s0" ] || fail "stamp: unchanged when an untracked file is added"
echo b > "$a/new.txt"
s3=$(st tree_stamp); [ "$s3" != "$s2" ] && [ "$s3" != "$s0" ] || fail "stamp: unchanged when an untracked file's content changes"
rm "$a/new.txt"
git -C "$a" commit -q --allow-empty -m empty
[ "$(st tree_stamp)" != "$s0" ] || fail "stamp: unchanged when HEAD changes"
git -C "$a" reset -q --hard HEAD~1
# The stamps live in the worktree's git directory; a full stamp satisfies a fast request, not the
# reverse.
rm -f "$gd"/afe-green-*
st stamp_matches fast && fail "stamp: a fast request matches without a stamp"
st stamp_write full && [ "$(cat "$gd/afe-green-full")" = "$s0" ] || fail "stamp: stamp_write full does not store the tree stamp in the git directory"
st stamp_matches fast && st stamp_matches full || fail "stamp: a full stamp does not satisfy a fast request"
rm -f "$gd"/afe-green-* && st stamp_write fast
st stamp_matches fast && ! st stamp_matches full || fail "stamp: a fast stamp does not match, or satisfies a full request"
rm -f "$gd"/afe-green-*
# scripts/check.sh: parts in order, one line each when they pass; the full stamp on success;
# --if-changed on an unchanged tree runs nothing.
(cd "$a" && scripts/check.sh > "$work/check1.log" 2>&1) || { cat "$work/check1.log"; fail "check.sh: fails on variant A"; }
[ "$(cat "$work/check1.log")" = "$(printf '#### %s: passed\n' scripts/check-project.sh scripts/check-docs.sh scripts/check-decisions.sh scripts/check-template.sh; echo '#### all checks passed')" ] ||
  { cat "$work/check1.log"; fail "check.sh: a passing run prints more than one line per part, or the parts are out of order"; }
[ "$(st stamp_read full)" = "$s0" ] || fail "check.sh: a passing run does not store the full stamp"
(cd "$a" && scripts/check.sh --if-changed > "$work/check2.log" 2>&1) && [ "$(cat "$work/check2.log")" = "#### unchanged since the last passing run" ] ||
  { cat "$work/check2.log"; fail "check.sh --if-changed: runs on an unchanged tree"; }
# In GitHub Actions the stamp is neither read nor written.
(cd "$a" && GITHUB_ACTIONS=true scripts/check.sh --if-changed > "$work/check3.log" 2>&1) && grep -qx '#### all checks passed' "$work/check3.log" ||
  { cat "$work/check3.log"; fail "check.sh --if-changed: reads the stamp in GitHub Actions"; }
echo x >> "$a/README.md"
(cd "$a" && GITHUB_ACTIONS=true scripts/check.sh > "$work/check3.log" 2>&1)
[ "$(st stamp_read full)" = "$s0" ] || fail "check.sh: writes the stamp in GitHub Actions"
(cd "$a" && scripts/check.sh --if-changed > "$work/check4.log" 2>&1) && grep -qx '#### all checks passed' "$work/check4.log" &&
  [ "$(st stamp_read full)" = "$(st tree_stamp)" ] || { cat "$work/check4.log"; fail "check.sh --if-changed: does not run, or store the stamp, on a changed tree"; }
# A failing part: the run goes on, the failure shows at most 60 lines, and no stamp is written.
printf '#!/usr/bin/env bash\nseq 1 100; exit 1\n' > "$work/fail-part" && cp "$a/scripts/check-project.sh" "$work/check-project.keep" &&
  cat "$work/fail-part" > "$a/scripts/check-project.sh"
before=$(st stamp_read full)
(cd "$a" && scripts/check.sh > "$work/check5.log" 2>&1) && fail "check.sh: passes with a failing part"
grep -qx '#### scripts/check-project.sh: failed (exit 1)' "$work/check5.log" && grep -qx 100 "$work/check5.log" && ! grep -qx 40 "$work/check5.log" &&
  grep -qx '#### scripts/check-docs.sh: passed' "$work/check5.log" && [ "$(st stamp_read full)" = "$before" ] ||
  { cat "$work/check5.log"; fail "check.sh: a failing part stops the run, prints more than its last 60 lines, or stores the stamp"; }
(cd "$a" && scripts/check.sh --verbose > "$work/check6.log" 2>&1)
grep -qx 1 "$work/check6.log" && grep -qx '#### scripts/check-project.sh' "$work/check6.log" || { cat "$work/check6.log"; fail "check.sh --verbose: does not print every line"; }
cp "$work/check-project.keep" "$a/scripts/check-project.sh" && gitc "$a" checkout -q -- README.md && rm -f "$gd"/afe-green-*
