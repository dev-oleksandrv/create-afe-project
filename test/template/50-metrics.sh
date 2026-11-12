# pr-metrics.sh on merged pull requests of variant A. Needs $a from 10-variant-a.sh.
echo "== metrics of merged pull requests on variant A"
# A stand-in for gh that answers `gh pr list` with three merged pull requests: two in the period,
# one of them without a Metrics section, and one before it.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || { echo "unexpected gh call: $*" >&2; exit 1; }
cat <<'JSON'
[
 {
  "number": 3,
  "createdAt": "2026-10-20T04:00:00Z",
  "mergedAt": "2026-10-20T10:00:00Z",
  "body": "## Summary\n\n- x\n\n## Metrics\n\n| Sensor | Class | Found | Fixed | Limit | Declined |\n| --- | --- | --- | --- | --- | --- |\n| code-review | blocker | 1 | 1 | 0 | 0 |\n| code-review | suggestion | 2 | 1 | 1 | 0 |\n| docs-review | suggestion | 0 | 0 | 0 | 0 |\n\n| Measure | Value |\n| --- | --- |\n| First check.sh | fail |\n| Ralph iterations | 3 |\n| Santa rounds | 0 |\n| Owner interventions | 1 (a question) |\n| Files outside the scope | 2 (a, b) |\n| Regression of | #1 |\n\n## Notes for the owner\n\n| code-review | blocker | 9 | 9 | 0 | 0 |\n"
 },
 {
  "number": 2,
  "createdAt": "2026-10-10T08:00:00Z",
  "mergedAt": "2026-10-10T10:00:00Z",
  "body": "## Summary\n\n- x\n"
 },
 {
  "number": 1,
  "mergedAt": "2026-09-01T10:00:00Z",
  "body": "## Metrics\n\n| code-review | blocker | 5 | 5 | 0 | 0 |\n"
 }
]
JSON
EOF
chmod +x "$work/bin/gh"
if out=$(cd "$a" && PATH="$work/bin:$PATH" scripts/pr-metrics.sh --since 2026-10-01 2>&1); then
  for l in 'merged pull requests since 2026-10-01: 2, with a Metrics section: 1' 'first check.sh passed: 0 of 1 pull requests' \
    'ralph iterations: total 3, median 3, max 3, in 1 pull requests' 'owner interventions: total 1, median 1, max 1, in 1 pull requests' \
    'files outside the scope: total 2, median 2, max 2, in 1 pull requests' 'regression rate: 1 of 1 pull requests repair another one' \
    'hours to merge: total 8, median 4, max 6, in 2 pull requests' \
    'sensors without a finding in the period: docs-review'; do
    printf '%s\n' "$out" | grep -q -F "$l" || { printf '%s\n' "$out"; fail "pr-metrics: no line '$l'"; }
  done
  printf '%s\n' "$out" | grep -q -E '^code-review +blocker +1 +1 +0 +0 +1$' && printf '%s\n' "$out" | grep -q -E '^code-review +suggestion +2 +1 +1 +0 +1$' &&
    ! printf '%s\n' "$out" | grep -q WARNING || { printf '%s\n' "$out"; fail "pr-metrics: wrong totals"; }
else
  printf '%s\n' "$out"; fail "pr-metrics fails"
fi
out=$(cd "$a" && PATH="$work/bin:$PATH" scripts/pr-metrics.sh --since 2026-01-01 --limit 3 2>&1)
printf '%s\n' "$out" | grep -q 'WARNING: gh listed 3 pull requests' || { printf '%s\n' "$out"; fail "pr-metrics: no warning when --limit cuts the period"; }
