#!/usr/bin/env bash
# Project checks (docs/documentation-rules.md, section 9): runs every scripts/checks.d/*.sh in name
# order. A project adds its own checks there; the template never writes to that directory.
set -uo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

checks=(scripts/checks.d/*.sh)
if [ "${#checks[@]}" -eq 0 ]; then
  echo "SKIP: no project checks in scripts/checks.d/"
  exit 0
fi
failures=0
for c in "${checks[@]}"; do
  echo "== project check: $c"
  if [ ! -x "$c" ]; then
    echo "FAIL: $c is not executable"
    failures=$((failures + 1))
  elif ! "$c"; then
    failures=$((failures + 1))
  fi
done
if [ "$failures" -gt 0 ]; then
  echo "== project checks failed: $failures"
  exit 1
fi
echo "== project checks passed"
