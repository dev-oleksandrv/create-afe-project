# The generated "Gate files" section, scripts/check-decisions.sh --gate-section, on variant A.
# Needs $a from 10-variant-a.sh, expect_pass from 30-negative.sh, and $work/r-none.md from
# 40-readiness.sh.
echo "== generated Gate files section on variant A"
gates() { scripts/check-decisions.sh --gate-section --base main; }
# gated: a change of three gate paths (one added, one changed, one deleted), a high path, and code.
gated() {
  mkdir -p scripts/checks.d src/auth && printf '#!/bin/sh\n' > scripts/checks.d/20-x.sh && echo x >> .claude/harness.conf &&
    rm .github/workflows/decisions.yml && echo x > src/auth/login.py && echo x > src/app.py
}
export -f gates gated
expect_pass "no gate path: the section is None" bash -c '[ "$(gates)" = None ]'
expect_pass "one bullet per gate path the change touches, deleted paths included, nothing else" bash -c 'gated &&
  [ "$(gates)" = "$(printf -- "- \`.claude/harness.conf\`\n- \`.github/workflows/decisions.yml\`\n- \`scripts/checks.d/20-x.sh\`")" ]'
expect_pass "the generated section pasted under Gate files passes readiness" bash -c 'gated &&
  { cat "$work/r-none.md"; printf "\n## Gate files\n\n"; gates; } > "$work/r-gen.md" && scripts/check-decisions.sh --ready --base main --pr-body "$work/r-gen.md"'
expect_pass "without the section, readiness fails on each gate path" bash -c 'gated && out=$(scripts/check-decisions.sh --ready --base main --pr-body "$work/r-none.md"); [ $? -eq 1 ] &&
  for p in .claude/harness.conf .github/workflows/decisions.yml scripts/checks.d/20-x.sh; do
    printf "%s\n" "$out" | grep -q "^FAIL: $p: class gate; list it under .Gate files." || exit 1; done'
expect_pass "a section that misses one gate path fails on that path only" bash -c 'gated &&
  { cat "$work/r-none.md"; printf "\n## Gate files\n\n"; gates | grep -v harness.conf; } > "$work/r-part.md" &&
  out=$(scripts/check-decisions.sh --ready --base main --pr-body "$work/r-part.md"); [ $? -eq 1 ] &&
  [ "$(printf "%s\n" "$out" | grep -c "class gate; list it")" = 1 ] && printf "%s\n" "$out" | grep -q "^FAIL: .claude/harness.conf: class gate"'
