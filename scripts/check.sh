#!/usr/bin/env bash
# All checks: the single local entry point. Runs, in this order, scripts/check-project.sh (the
# project's code checks), scripts/check-docs.sh, scripts/check-decisions.sh, and
# scripts/check-template.sh, every part even when an earlier one fails, then reports which parts
# failed; exit 0 means every part passed. A passing part prints one line, a failing part at most
# the last 60 lines of its output. On success it stores the full green stamps of both kinds, code
# and docs (scripts/lib/stamp.sh), and the base of the change (scripts/lib/git-base.sh), on which
# scripts/check-decisions.sh depends, as the full stamp of kind base: a local cache that GitHub
# Actions never reads or writes.
#
# Usage: scripts/check.sh [--verbose] [--if-changed]
#   --verbose     print the whole output of every part.
#   --if-changed  when the tree and the base are unchanged since the last passing run (the full
#                 stamps of the kinds code, docs, and base match), print one line and exit 0
#                 without running anything; safe to call often.
set -uo pipefail
cd "$(dirname "$0")/.."

verbose= if_changed=
for arg in "$@"; do
  case "$arg" in
    --verbose) verbose=1 ;;
    --if-changed) if_changed=1 ;;
    *) echo "usage: scripts/check.sh [--verbose] [--if-changed]" >&2; exit 2 ;;
  esac
done

code_stamp= docs_stamp= base_stamp=
if [ -z "${GITHUB_ACTIONS:-}" ] && git rev-parse --git-dir > /dev/null 2>&1; then
  # shellcheck source=scripts/lib/stamp.sh
  . scripts/lib/stamp.sh
  # shellcheck source=scripts/lib/git-base.sh
  . scripts/lib/git-base.sh
  { IFS= read -r code_stamp; IFS= read -r docs_stamp; } < <(tree_stamps)
  base_stamp=$(resolve_base 2> /dev/null)
  if [ -n "$if_changed" ] && [ -n "$code_stamp" ] && [ -n "$docs_stamp" ] && [ -n "$base_stamp" ] &&
    [ "$(stamp_read full code)" = "$code_stamp" ] &&
    [ "$(stamp_read full docs)" = "$docs_stamp" ] &&
    [ "$(stamp_read full base)" = "$base_stamp" ]; then
    echo "#### unchanged since the last passing run"
    exit 0
  fi
fi

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
run scripts/check-decisions.sh
run scripts/check-template.sh

if [ "${#failed[@]}" -gt 0 ]; then
  echo "#### failed: ${failed[*]}"
  exit 1
fi
if [ -n "$code_stamp" ] && [ -n "$docs_stamp" ] && [ -n "$base_stamp" ]; then
  stamp_write full code "$code_stamp" && stamp_write full docs "$docs_stamp" && stamp_write full base "$base_stamp"
fi
echo "#### all checks passed"
