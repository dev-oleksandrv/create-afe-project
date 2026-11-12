# The protect hook denies a push to the default branch once the remote has it. Needs $a, hook, and
# $ghp from 10-, 60-, and 65-*.sh, and $work/r-none.md from 40-readiness.sh.
# A pushed feature branch must still be compared with main, not with its own upstream.
git init -q --bare "$work/origin.git"
git -C "$a" remote add origin "$work/origin.git" && gitc "$a" push -q origin main
# Once the remote has the default branch, a push to it is denied; a push of another branch is not.
for c in "git push origin main" "git push" "git push origin HEAD:main" "git -C . push origin feature:refs/heads/main"; do
  hook deny '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
# A token in the command must not turn the deny into an approvable prompt.
hook deny '{"tool_name":"Bash","tool_input":{"command":"GH_TOKEN='"$ghp"' git push origin main"}}'
gitc "$a" switch -q -c pushed && printf -- '---\nstatus: proposed\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' > "$a/docs/decisions/0001-test.md"
(cd "$a" && scripts/gen-decisions-index.sh > docs/decisions/README.md) && gitc "$a" add -A && gitc "$a" commit -q -m record
gitc "$a" push -q -u origin pushed
(cd "$a" && scripts/check-decisions.sh --ready --pr-body "$work/r-none.md" > "$work/pushed.log" 2>&1) &&
  fail "readiness on a pushed feature branch misses the proposed record"
grep -q "0001-test.md: still 'proposed'" "$work/pushed.log" || { cat "$work/pushed.log"; fail "readiness on a pushed feature branch fails for another reason"; }
gitc "$a" switch -q main && gitc "$a" branch -q -D pushed && git -C "$a" remote remove origin
