# The green stamp (scripts/lib/stamp.sh) and scripts/check.sh: quiet output, --if-changed, and the
# full stamp, which GitHub Actions never reads or writes. Needs $a from 10-variant-a.sh.
echo "== the green stamp and scripts/check.sh"
st() { (cd "$a" && . scripts/lib/stamp.sh && "$@"); }
gd=$(git -C "$a" rev-parse --absolute-git-dir)
# Two kinds: docs (*.md) and code (every other path); each changes only with its own files.
c0=$(st tree_stamp code) d0=$(st tree_stamp docs)
printf '%s\n%s' "$c0" "$d0" | grep -qvE '^[0-9a-f]{64}$' && fail "stamp: tree_stamp is not a SHA-256 ($c0, $d0)"
[ "$(st tree_stamp code)" = "$c0" ] && [ "$(st tree_stamp docs)" = "$d0" ] && [ "$c0" != "$d0" ] ||
  fail "stamp: tree_stamp is not stable, or the kinds do not differ"
echo x >> "$a/README.md"
[ "$(st tree_stamp docs)" != "$d0" ] && [ "$(st tree_stamp code)" = "$c0" ] || fail "stamp: a Markdown change does not change docs alone"
gitc "$a" checkout -q -- README.md
[ "$(st tree_stamp docs)" = "$d0" ] || fail "stamp: docs differs after a tracked file is restored"
echo x >> "$a/.claude/harness.conf"
[ "$(st tree_stamp code)" != "$c0" ] && [ "$(st tree_stamp docs)" = "$d0" ] || fail "stamp: a change of a tracked file other than Markdown does not change code alone"
gitc "$a" checkout -q -- .claude/harness.conf
[ "$(st tree_stamp code)" = "$c0" ] || fail "stamp: code differs after a tracked file is restored"
echo a > "$a/new.txt"
s2=$(st tree_stamp code); [ "$s2" != "$c0" ] || fail "stamp: unchanged when an untracked file is added"
echo b > "$a/new.txt"
s3=$(st tree_stamp code); [ "$s3" != "$s2" ] && [ "$s3" != "$c0" ] || fail "stamp: unchanged when an untracked file's content changes"
rm "$a/new.txt"
echo a > "$a/new.md"
[ "$(st tree_stamp docs)" != "$d0" ] && [ "$(st tree_stamp code)" = "$c0" ] || fail "stamp: an untracked Markdown file does not change docs alone"
rm "$a/new.md"
# A name that git quotes (a double quote, a tab): its content still counts.
odd=$(printf 'odd"na\tme.txt')
echo a > "$a/$odd"
s4=$(st tree_stamp code); echo b > "$a/$odd"
s5=$(st tree_stamp code); [ "$s5" != "$s4" ] || fail "stamp: unchanged when an untracked file with a quoted name changes"
rm "$a/$odd"
[ "$(st tree_stamp code)" = "$c0" ] || fail "stamp: differs after an untracked file with a quoted name is removed"
# The stamp is over content, not HEAD: an empty commit changes nothing, a commit of Markdown alone
# keeps the code stamp.
git -C "$a" commit -q --allow-empty -m empty
[ "$(st tree_stamp code)" = "$c0" ] && [ "$(st tree_stamp docs)" = "$d0" ] || fail "stamp: changes with HEAD alone"
echo x >> "$a/README.md" && gitc "$a" commit -q -am docs
[ "$(st tree_stamp code)" = "$c0" ] && [ "$(st tree_stamp docs)" != "$d0" ] || fail "stamp: a commit of Markdown alone changes the code stamp, or not the docs stamp"
git -C "$a" reset -q --hard HEAD~2
# The stamps live in the worktree's git directory, one file per scope and kind; a full stamp
# satisfies a fast request of its kind, not the reverse.
rm -f "$gd"/afe-green-*
st stamp_matches fast code && fail "stamp: a fast request matches without a stamp"
st stamp_write full code && [ "$(cat "$gd/afe-green-full-code")" = "$c0" ] || fail "stamp: stamp_write full code does not store the code stamp in the git directory"
st stamp_matches fast code && st stamp_matches full code || fail "stamp: a full stamp does not satisfy a fast request"
st stamp_matches fast docs && fail "stamp: a code stamp satisfies a docs request"
rm -f "$gd"/afe-green-* && st stamp_write fast docs && [ "$(cat "$gd/afe-green-fast-docs")" = "$d0" ] || fail "stamp: stamp_write fast docs does not store the docs stamp"
st stamp_matches fast docs && ! st stamp_matches full docs || fail "stamp: a fast stamp does not match, or satisfies a full request"
rm -f "$gd"/afe-green-*
# scripts/check.sh: parts in order, one line each when they pass; the full stamp on success;
# --if-changed on an unchanged tree runs nothing.
(cd "$a" && scripts/check.sh > "$work/check1.log" 2>&1) || { cat "$work/check1.log"; fail "check.sh: fails on variant A"; }
[ "$(cat "$work/check1.log")" = "$(printf '#### %s: passed\n' scripts/check-project.sh scripts/check-docs.sh scripts/check-decisions.sh scripts/check-template.sh; echo '#### all checks passed')" ] ||
  { cat "$work/check1.log"; fail "check.sh: a passing run prints more than one line per part, or the parts are out of order"; }
[ "$(st stamp_read full code)" = "$c0" ] && [ "$(st stamp_read full docs)" = "$d0" ] || fail "check.sh: a passing run does not store the full stamps of both kinds"
(cd "$a" && scripts/check.sh --if-changed > "$work/check2.log" 2>&1) && [ "$(cat "$work/check2.log")" = "#### unchanged since the last passing run" ] ||
  { cat "$work/check2.log"; fail "check.sh --if-changed: runs on an unchanged tree"; }
# --if-changed skips only when both kinds match: a stale stamp of either kind runs the checks.
for k in code docs; do
  echo stale > "$gd/afe-green-full-$k"
  (cd "$a" && scripts/check.sh --if-changed > "$work/check2.log" 2>&1) && grep -qx '#### all checks passed' "$work/check2.log" ||
    { cat "$work/check2.log"; fail "check.sh --if-changed: skips with a stale $k stamp"; }
done
# In GitHub Actions the stamp is neither read nor written.
(cd "$a" && GITHUB_ACTIONS=true scripts/check.sh --if-changed > "$work/check3.log" 2>&1) && grep -qx '#### all checks passed' "$work/check3.log" ||
  { cat "$work/check3.log"; fail "check.sh --if-changed: reads the stamp in GitHub Actions"; }
echo x >> "$a/README.md"
(cd "$a" && GITHUB_ACTIONS=true scripts/check.sh > "$work/check3.log" 2>&1)
[ "$(st stamp_read full docs)" = "$d0" ] || fail "check.sh: writes the stamp in GitHub Actions"
(cd "$a" && scripts/check.sh --if-changed > "$work/check4.log" 2>&1) && grep -qx '#### all checks passed' "$work/check4.log" &&
  [ "$(st stamp_read full docs)" = "$(st tree_stamp docs)" ] || { cat "$work/check4.log"; fail "check.sh --if-changed: does not run, or store the stamp, on a changed tree"; }
# A failing part: the run goes on, the failure shows at most 60 lines, and no stamp is written.
printf '#!/usr/bin/env bash\nseq 1 100; exit 1\n' > "$work/fail-part" && cp "$a/scripts/check-project.sh" "$work/check-project.keep" &&
  cat "$work/fail-part" > "$a/scripts/check-project.sh"
before=$(st stamp_read full code)
(cd "$a" && scripts/check.sh > "$work/check5.log" 2>&1) && fail "check.sh: passes with a failing part"
grep -qx '#### scripts/check-project.sh: failed (exit 1)' "$work/check5.log" && grep -qx 100 "$work/check5.log" && ! grep -qx 40 "$work/check5.log" &&
  grep -qx '#### scripts/check-docs.sh: passed' "$work/check5.log" && [ "$(st stamp_read full code)" = "$before" ] ||
  { cat "$work/check5.log"; fail "check.sh: a failing part stops the run, prints more than its last 60 lines, or stores the stamp"; }
(cd "$a" && scripts/check.sh --verbose > "$work/check6.log" 2>&1)
grep -qx 1 "$work/check6.log" && grep -qx '#### scripts/check-project.sh' "$work/check6.log" || { cat "$work/check6.log"; fail "check.sh --verbose: does not print every line"; }
cp "$work/check-project.keep" "$a/scripts/check-project.sh" && gitc "$a" checkout -q -- README.md && rm -f "$gd"/afe-green-*
