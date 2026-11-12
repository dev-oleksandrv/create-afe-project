#!/usr/bin/env bash
# Template tests (docs/maintaining.md, section 3): render the template in four projects and run the
# generated project's checks, prove that the checks catch violations, and confirm that this
# repository's own template-owned files match template/.
# The tests are in test/template/: lib.sh sets up the shared state, then each [0-9]*.sh is sourced
# in name order into this shell, so a later file reuses the projects and helpers of earlier ones
# and adds to the same failure count.
set -uo pipefail
cd "$(dirname "$0")/../.."
. test/template/lib.sh
for template_test in "$root"/test/template/[0-9]*.sh; do
  . "$template_test"
done

if [ "$failures" -gt 0 ]; then
  echo "== template tests failed: $failures"
  exit 1
fi
echo "== template tests passed"
