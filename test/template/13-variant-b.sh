# Variant B: renders the self-hosted project with code-review on and the acceptance check off into
# $b, which later files reuse. Needs lib.sh only.
echo "== variant B: self-hosted runner, code-review on, acceptance check off"
b="$work/b"
render "$b" --data ci_runner=self-hosted --data code_review=true --data acceptance_check=false ||
  fail "variant B does not render"
(cd "$b" && scripts/check.sh > "$work/b.log" 2>&1) || { cat "$work/b.log"; fail "variant B: scripts/check.sh fails"; }
grep -q '"self-hosted"' "$b/.github/workflows/check.yml" || fail "variant B: check.yml lacks the self-hosted default"
[ -f "$b/.github/workflows/code-review.yml" ] && [ -f "$b/.claude/skills/review-code/SKILL.md" ] ||
  fail "variant B: code-review files are missing although the module is on"
grep -q '"self-hosted"' "$b/.github/workflows/code-review.yml" || fail "variant B: code-review.yml lacks the self-hosted default"
[ ! -e "$b/scripts/check-acceptance.sh" ] && ! grep -qx 'scripts/check-acceptance.sh' "$b/.template/owned.txt" ||
  fail "variant B: the acceptance check exists although the module is off"
