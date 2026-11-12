# Smoke test: a documentation-only project with every module off, rendered into $c. Needs
# $work/r-none.md from 40-readiness.sh.
echo "== smoke: a documentation-only project, every module off"
c="$work/c"
render "$c" --data code_review=false --data secret_scan=false \
  --data acceptance_check=false --data fail_without_change=false || fail "the documentation-only project does not render"
(cd "$c" && scripts/check.sh > "$work/c.log" 2>&1) || { cat "$work/c.log"; fail "documentation-only: scripts/check.sh fails"; }
[ ! -e "$c/scripts/check-acceptance.sh" ] && [ ! -e "$c/scripts/fail-without-change.sh" ] && [ ! -e "$c/.github/workflows/fail-without-change.yml" ] &&
  [ ! -e "$c/.github/workflows/secret-scan.yml" ] && [ ! -e "$c/.github/workflows/code-review.yml" ] && [ ! -e "$c/.claude/skills/review-code" ] &&
  ! grep -r -q gitleaks "$c" --exclude-dir=.git ||
  fail "documentation-only: module scripts exist although the modules are off"
mkdir -p "$c/docs/plans" && echo x > "$c/docs/plans/x.md"
(cd "$c" && scripts/check-decisions.sh --ready --base main --pr-body "$work/r-none.md" > "$work/c-ready.log" 2>&1 &&
  scripts/check-decisions.sh --classes --base main | grep -qx "review	none") ||
  { cat "$work/c-ready.log"; fail "documentation-only: readiness or classes fail on a document change"; }
