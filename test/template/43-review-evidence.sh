# The review evidence of an outside review engine (scripts/check-review-evidence.mjs), on
# variant A. Needs $a from 10-variant-a.sh.
echo "== review evidence"
# B the base, C an earlier commit of the branch, H the head, X another commit.
B=1111111111111111111111111111111111111111 C=2222222222222222222222222222222222222222
H=3333333333333333333333333333333333333333 X=4444444444444444444444444444444444444444
# evl <kind> <base> <head> [dirty] [coverage] [provider] [model] [role] [input]: a review or confirm line.
evl() {
  local model=${7-gpt-5}
  [ "$model" = null ] || model="\"$model\""
  printf '{"kind":"%s","role":"%s","input":"%s","provider":"%s","model":%s,"base":"%s","head":"%s","dirty":%s,"coverage":"%s","at":"2026-11-15T10:00:00Z"}\n' \
    "$1" "${8:-general}" "${9:-diff}" "${6:-codex}" "$model" "$2" "$3" "${4:-false}" "${5:-full}"
}
# fd <severity> <answer>: a finding line.
fd() { printf '{"kind":"finding","role":"general","severity":"%s","where":"src/x.ts:3","answer":"%s","note":"x"}\n' "$1" "$2"; }
# evidence <expected exit> <what> <file content> [options]: runs the validator, by default with
# --head H --base B.
evidence() {
  local code
  printf '%s\n' "$3" > "$work/ev.jsonl"
  shift 3 2> /dev/null
  (cd "$a" && scripts/check-review-evidence.mjs ${*:---head $H --base $B} "$work/ev.jsonl" > "$work/ev.out" 2> "$work/ev.err"); code=$?
  [ "$code" = "$ev_exit" ] || { cat "$work/ev.out" "$work/ev.err"; fail "review evidence: $ev_what exits $code, not $ev_exit"; }
  [ "$ev_exit" = 0 ] || [ -s "$work/ev.err" ] || fail "review evidence: $ev_what gives no reason"
}
ev() { ev_exit=$1 ev_what=$2; evidence "$@"; }
printed() { [ "$(cat "$work/ev.out")" = "$1" ] || { cat "$work/ev.out"; fail "review evidence: $ev_what prints '$(cat "$work/ev.out")', not '$1'"; }; }
ev 0 "a full review at the head" "$(evl review $B $H)
$(fd blocker fixed)
$(fd non-blocker open)
$(evl review $B $H false full other m planner plan)"
printed "Review: external, codex (gpt-5), coverage full, head 3333333"
# A line that does not qualify never counts, and its provider is not printed.
ev 0 "a dirty partial review by one provider, then a clean full one by another" "$(evl review $B $H true partial kimi k2)
$(evl review $B $H false tools claude null)"
printed "Review: external, claude, coverage tools, head 3333333"
ev 1 "a dirty review alone" "$(evl review $B $H true full)"
ev 1 "a review with partial coverage alone" "$(evl review $B $H false partial)"
ev 1 "only a confirm line" "$(evl confirm $B $H)"
ev 1 "a review of the last commit, not of the branch" "$(evl review $C $H)"
grep -q "no clean review of the diff from the base $B" "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: a review from another base does not name the base"; }
ev 1 "a review of another head without a confirm" "$(evl review $B $C)"
grep -q "the reviews end at $C, not at the head $H" "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: a wrong head is not named"; }
# The chain of confirms from the start to the head.
ev 0 "a review, then a confirm of the fix" "$(evl review $B $C)
$(fd blocker fixed)
$(evl confirm $C $H false full claude opus)"
printed "Review: external, codex (gpt-5), claude (opus), coverage full, head 3333333"
ev 0 "two confirms in a row" "$(evl review $B $C)
$(evl confirm $C $X)
$(evl confirm $X $H)"
ev 1 "a confirm from another commit" "$(evl review $B $C)
$(evl confirm $X $H)"
ev 1 "a dirty confirm" "$(evl review $B $C)
$(evl confirm $C $H true full)"
# Only a confirm of the diff moves the chain: one of a plan or a question reviewed no change.
ev 1 "a confirm of a plan" "$(evl review $B $C)
$(evl confirm $C $H false full codex gpt-5 general plan)"
ev 1 "a confirm of a question" "$(evl review $B $C)
$(evl confirm $C $H false full codex gpt-5 general question)"
ev 1 "a confirm before the review it confirms" "$(evl confirm $C $H)
$(evl review $B $C)"
ev 1 "a later full review restarts the chain" "$(evl review $B $C)
$(evl confirm $C $H)
$(evl review $B $X)"
# --level two needs two roles in the start set; a later line of a role replaces an earlier one.
ev 1 "level two with one role" "$(evl review $B $H)" --head $H --base $B --level two
ev 0 "level two with two roles" "$(evl review $B $H false full codex gpt-5 general)
$(evl review $B $H false full claude opus security)" --head $H --base $B --level two
printed "Review: external, codex (gpt-5), claude (opus), coverage full, head 3333333"
ev 1 "level two with one role twice" "$(evl review $B $H false full codex gpt-5 general)
$(evl review $B $H false full claude opus general)" --head $H --base $B --level two
ev 0 "a later line of a role replaces an earlier one" "$(evl review $B $H false full codex gpt-5 general)
$(evl review $B $H false full claude opus general)"
printed "Review: external, claude (opus), coverage full, head 3333333"
ev 1 "level two with the second role at an earlier head" "$(evl review $B $C false full claude opus security)
$(evl review $B $H false full codex gpt-5 general)" --head $H --base $B --level two
# Findings and the form of the file.
ev 1 "an open blocker" "$(evl review $B $H)
$(fd blocker open)"
grep -q 'open blocker: src/x.ts:3 (line 2)' "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: an open blocker is not named"; }
ev 1 "a broken JSON line" "$(evl review $B $H)
{\"kind\":"
grep -q 'line 2: not valid JSON' "$work/ev.err" || { cat "$work/ev.err"; fail "review evidence: a broken line is not named"; }
ev 1 "an unknown kind" "$(evl review $B $H)
{\"kind\":\"vote\"}"
ev 1 "a finding with an unknown answer" "$(evl review $B $H)
$(fd blocker later)"
ev 1 "no review line of the diff" "$(evl review $B $H false full codex gpt-5 general plan)
$(fd non-blocker fixed)"
# The defaults: HEAD, and the base of scripts/lib/git-base.sh (on main of variant A, HEAD itself).
h=$(git -C "$a" rev-parse HEAD)
ev 0 "the default head and base" "$(evl review "$h" "$h")" --level one
printed "Review: external, codex (gpt-5), coverage full, head ${h:0:7}"
ev 1 "the default head and base, with a review of another base" "$(evl review $B "$h")" --level one
for u in "" "--head" "--level three $work/ev.jsonl" "--head nothex $work/ev.jsonl" "--head $H --base $B $work/none.jsonl" "--head $H a b"; do
  # shellcheck disable=SC2086
  (cd "$a" && scripts/check-review-evidence.mjs $u > /dev/null 2>&1); [ $? -eq 2 ] || fail "review evidence: usage '$u' does not exit 2"
done
