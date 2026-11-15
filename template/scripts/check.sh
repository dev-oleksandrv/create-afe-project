#!/usr/bin/env bash
# All checks: the single local entry point, and what CI runs. In this order: scripts/check-project.sh
# (the project's code checks), scripts/check-docs.sh (links), and scripts/check-template.sh
# (template integrity); every part runs even when an earlier one fails, then it reports which
# parts failed. Exit 0 means every part passed. A passing part prints one line, a failing part at
# most the last 60 lines of its output.
#
# Usage: scripts/check.sh [--verbose]
#   --verbose  print the whole output of every part.
set -uo pipefail
cd "$(dirname "$0")/.."

verbose=
for arg in "$@"; do
  case "$arg" in
    --verbose) verbose=1 ;;
    *) echo "usage: scripts/check.sh [--verbose]" >&2; exit 2 ;;
  esac
done

failed=()
run() {
  local out code
  if [ -n "$verbose" ]; then
    echo "#### $1"
    "$@" || failed+=("$1")
    return
  fi
  out=$("$@" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    echo "#### $1: passed"
  else
    echo "#### $1: failed (exit $code)"
    printf '%s\n' "$out" | tail -n 60
    failed+=("$1")
  fi
}
run scripts/check-project.sh
run scripts/check-docs.sh
run scripts/check-template.sh

if [ "${#failed[@]}" -gt 0 ]; then
  echo "#### failed: ${failed[*]}"
  exit 1
fi
echo "#### all checks passed"
