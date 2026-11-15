# Smoke test: a documentation-only project with every module off, rendered into $c. Needs
# lib.sh only.
echo "== smoke: a documentation-only project, every module off"
c="$work/c"
render "$c" --data code_review=false --data secret_scan=false || fail "the documentation-only project does not render"
(cd "$c" && scripts/check.sh > "$work/c.log" 2>&1) || { cat "$work/c.log"; fail "documentation-only: scripts/check.sh fails"; }
[ ! -e "$c/.github/workflows/secret-scan.yml" ] && [ ! -e "$c/.github/workflows/code-review.yml" ] && [ ! -e "$c/.claude/skills/review-code" ] &&
  ! grep -r -q gitleaks "$c" --exclude-dir=.git ||
  fail "documentation-only: module files exist although the modules are off"
[ "$(cd "$c/.github/workflows" && ls | tr '\n' ' ')" = 'check.yml ' ] || fail "documentation-only: the workflows are not check.yml alone"
# An answer to a removed question, such as from an older answers file, is ignored.
render "$work/c-old" --data acceptance_check=true --data fail_without_change=true || fail "a project with answers to removed questions does not render"
! grep -q 'acceptance_check\|fail_without_change' "$work/c-old/.afe-answers.json" || fail "the answers file records a removed question"
