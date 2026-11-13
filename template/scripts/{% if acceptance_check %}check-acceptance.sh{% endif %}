#!/usr/bin/env bash
# Acceptance check, the `acceptance_check` module: every identifier that the section "Acceptance
# and test plan" of a pull request description names, by ID_PATTERN of .claude/harness.conf,
# appears as a whole word in at least one test file of TEST_GLOBS. It does not judge whether that
# test proves the identifier; the review does. scripts/check-decisions.sh --ready runs it. It skips
# when TEST_GLOBS is empty or the section names no identifier. A project may replace it with a
# stricter check in scripts/checks.d/.
#
# Usage: scripts/check-acceptance.sh --pr-body <file>
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh

body=
while [ $# -gt 0 ]; do
  case "$1" in
    --pr-body) body="${2:?--pr-body needs a file}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -f "$body" ] || { echo "check-acceptance: --pr-body <file> is required" >&2; exit 2; }

echo "== acceptance: every identifier of the description is carried by a test file"
pattern=$(conf_get ID_PATTERN '(REQ|AC|INV)-[0-9]+')
globs=$(conf_get TEST_GLOBS)
[ -n "$globs" ] || { echo "SKIP: TEST_GLOBS is empty in .claude/harness.conf"; exit 0; }
ids=$(tr -d '\r' < "$body" |
  awk '/^## / {l = $0; sub(/[[:space:]]+$/, "", l); s = (l == "## Acceptance and test plan"); next} s' |
  grep -o -E -- "$pattern" | sort -u)
[ -n "$ids" ] || { echo "SKIP: the Acceptance section names no identifier"; exit 0; }
files=$(matching_files "$globs")

failures=0
while IFS= read -r id; do
  hit=$(printf '%s\n' "$files" | while IFS= read -r f; do
    [ -f "$f" ] && grep -q -F -w -- "$id" "$f" 2>/dev/null && { printf '%s\n' "$f"; break; }
  done)
  if [ -n "$hit" ]; then
    echo "ok: $id in $hit"
  else
    echo "FAIL: $id: no test file of TEST_GLOBS carries it"
    failures=$((failures + 1))
  fi
done <<< "$ids"
[ "$failures" -eq 0 ] || { echo "== acceptance check failed: $failures"; exit 1; }
echo "== acceptance check passed"
