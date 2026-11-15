# The review evidence of an outside review engine (scripts/check-review-evidence.mjs), on
# variant A. Needs $a from 10-variant-a.sh.
echo "== review evidence"
h=$(git -C "$a" rev-parse HEAD) other=0123456789abcdef0123456789abcdef01234567
# rv <kind> <head> <dirty> <coverage> [input]: a review or confirm line.
rv() { printf '{"kind":"%s","role":"general","input":"%s","provider":"codex","model":"gpt-5","base":"","head":"%s","dirty":%s,"coverage":"%s","at":"2026-11-15T10:00:00Z"}\n' "$1" "${5:-diff}" "$2" "$3" "$4"; }
# fd <severity> <answer>: a finding line.
fd() { printf '{"kind":"finding","role":"general","severity":"%s","where":"src/x.ts:3","answer":"%s","note":"x"}\n' "$1" "$2"; }
# evidence <expected exit> <what> <file content>: runs the validator on the content.
evidence() {
  printf '%s' "$3" > "$work/ev.jsonl"
  (cd "$a" && scripts/check-review-evidence.mjs --head "$h" "$work/ev.jsonl" > "$work/ev.out" 2> "$work/ev.err"); local code=$?
  [ "$code" = "$1" ] || { cat "$work/ev.out" "$work/ev.err"; fail "review evidence: $2 exits $code, not $1"; }
  [ "$1" = 0 ] || [ -s "$work/ev.err" ] || fail "review evidence: $2 gives no reason"
}
evidence 0 "a valid file" "$(rv review "$other" true partial)
$(rv review "$h" false tools)
$(fd blocker fixed)
$(fd non-blocker open)
$(rv review "$h" false full plan)
"
[ "$(cat "$work/ev.out")" = "Review: external, codex (gpt-5), coverage tools, head ${h:0:7}" ] ||
  { cat "$work/ev.out"; fail "review evidence: the line of a valid file is not the Review line"; }
evidence 1 "a review of another head" "$(rv review "$other" false full)"
grep -q "not $h" "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: a wrong head does not name the heads"; }
evidence 1 "a review of a dirty tree" "$(rv review "$h" true full)"
evidence 1 "a review with partial coverage" "$(rv review "$h" false partial)"
evidence 1 "an open blocker" "$(rv review "$h" false full)
$(fd blocker open)"
grep -q 'open blocker: src/x.ts:3 (line 2)' "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: an open blocker is not named"; }
evidence 1 "a broken JSON line" "$(rv review "$h" false full)
{\"kind\":"
grep -q 'line 2: not valid JSON' "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: a broken line is not named"; }
evidence 1 "an unknown kind" "$(rv review "$h" false full)
{\"kind\":\"vote\"}"
evidence 1 "a finding with an unknown answer" "$(rv review "$h" false full)
$(fd blocker later)"
evidence 1 "no review line of the diff" "$(rv review "$h" false full plan)
$(fd non-blocker fixed)"
evidence 0 "a confirm line as the last one" "$(rv review "$other" false full)
$(fd blocker fixed)
$(rv confirm "$h" false full | sed 's/"codex"/"claude"/; s/"gpt-5"/null/')"
[ "$(cat "$work/ev.out")" = "Review: external, claude, coverage full, head ${h:0:7}" ] ||
  { cat "$work/ev.out"; fail "review evidence: a confirm line as the last one does not give its Review line"; }
evidence 1 "a confirm line of another head after the review of this one" "$(rv review "$h" false full)
$(rv confirm "$other" false full)"
for u in "" "--head" "--head $h" "--head nothex $work/ev.jsonl" "--head $h $work/none.jsonl" "--head $h a b"; do
  # shellcheck disable=SC2086
  (cd "$a" && scripts/check-review-evidence.mjs $u > /dev/null 2>&1); [ $? -eq 2 ] || fail "review evidence: usage '$u' does not exit 2"
done
