#!/usr/bin/env bash
# The environment contract: one entry point for the commands an agent needs to set up, check, test
# end to end, and reset the project. `check` is scripts/check.sh; the others are the project's
# commands in .claude/harness.conf (SETUP, CHECK_FAST, E2E, RESET), run from the repository root
# with no stdin. A command that is not set prints SKIP and exits 0; otherwise the exit code is the
# command's, so a failure is machine-readable.
#
# Usage: scripts/env.sh setup|check|fast|e2e|reset
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh

case "${1:-}" in
  setup) key=SETUP ;;
  check) echo "== env check: scripts/check.sh"; exec scripts/check.sh < /dev/null ;;
  fast) key=CHECK_FAST ;;
  e2e) key=E2E ;;
  reset) key=RESET ;;
  *) echo "usage: scripts/env.sh setup|check|fast|e2e|reset" >&2; exit 2 ;;
esac
cmd=$(conf_get "$key")
if [ -z "$cmd" ]; then
  echo "SKIP: $key is not set in .claude/harness.conf"
  exit 0
fi
echo "== env $1: $cmd"
bash -c "$cmd" < /dev/null
