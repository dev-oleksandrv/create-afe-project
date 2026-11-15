#!/usr/bin/env bash
# Project checks: runs every scripts/checks.d/*.sh in name order. A project adds its own checks
# there; the template never writes to that directory. With CHECK_LOCK of .claude/harness.conf set,
# they run under that lock of the machine (scripts/lib/lock.sh), and the run fails when it cannot
# take the lock within CHECK_LOCK_WAIT seconds.
set -uo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh
# shellcheck source=scripts/lib/lock.sh
. scripts/lib/lock.sh

checks=(scripts/checks.d/*.sh)
if [ "${#checks[@]}" -eq 0 ]; then
  echo "SKIP: no project checks in scripts/checks.d/"
  exit 0
fi
check_lock scripts/check-project.sh || exit 1
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
