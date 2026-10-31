#!/usr/bin/env bash
# Unit tests of the create-afe-project CLI (docs/maintaining.md, section 3); its dependencies come
# from npm ci when node_modules is missing.
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -d node_modules ] || npm ci --silent
echo "== CLI unit tests"
node --test test/*.test.js > /tmp/afe-unit.$$ 2>&1 || { cat /tmp/afe-unit.$$; rm -f /tmp/afe-unit.$$; exit 1; }
tail -n 8 /tmp/afe-unit.$$ | grep -E '^ℹ (tests|pass|fail)'; rm -f /tmp/afe-unit.$$
