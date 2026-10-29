#!/usr/bin/env bash
# All checks: the single local entry point (AGENTS.md, section 6). Runs every part even when an
# earlier one fails, then reports which parts failed.
set -uo pipefail
cd "$(dirname "$0")/.."

failed=()
run() {
  echo "#### $1"
  "$@" || failed+=("$1")
}
run scripts/check-docs.sh
run scripts/check-decisions.sh
run scripts/check-template.sh
run scripts/check-project.sh

if [ "${#failed[@]}" -gt 0 ]; then
  echo "#### failed: ${failed[*]}"
  exit 1
fi
echo "#### all checks passed"
