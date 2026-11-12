# Variant B: renders the self-hosted project with dual review into $b, which later files reuse.
# Needs lib.sh only.
echo "== variant B: self-hosted runner, docs-review and code-review off, dual review on"
b="$work/b"
render "$b" --data ci_runner=self-hosted --data docs_review=false --data code_review=false --data dual_review=true ||
  fail "variant B does not render"
(cd "$b" && scripts/check.sh > "$work/b.log" 2>&1) || { cat "$work/b.log"; fail "variant B: scripts/check.sh fails"; }
[ ! -e "$b/.github/workflows/docs-review.yml" ] && [ ! -e "$b/.claude/skills/docs-review" ] ||
  fail "variant B: docs-review files exist although the module is off"
grep -q '"self-hosted"' "$b/.github/workflows/docs.yml" || fail "variant B: docs.yml lacks the self-hosted default"
! grep -r -n -i 'docs-review' "$b/AGENTS.md" "$b/docs" > "$work/b-grep.log" || { cat "$work/b-grep.log"; fail "variant B: documents mention docs-review"; }
[ ! -e "$b/.github/workflows/code-review.yml" ] && [ ! -e "$b/.claude/skills/review-code" ] ||
  fail "variant B: code-review files exist although the module is off"
! grep -r -n -i 'code-review\|review-code' "$b/AGENTS.md" "$b/docs" "$b/.claude/skills" > "$work/b-grep.log" || { cat "$work/b-grep.log"; fail "variant B: documents mention code-review"; }
[ -f "$b/.claude/skills/dual-review/SKILL.md" ] || fail "variant B: the dual-review skill is missing although the module is on"
