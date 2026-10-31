#!/usr/bin/env bash
# Stop hook: runs the project's own Stop hooks, .claude/hooks/project/stop/*.sh in name order, with
# the same input (docs/documentation-rules.md, section 9). A project hook blocks the agent by
# exiting with 2; its output goes to the agent. A hook that is not executable blocks too, because
# a silent gate is worse than a loud one. Other exit codes are reported without blocking.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || exit 0
cd "$root" || exit 0
shopt -s nullglob
input=$(cat)
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || { ralph_block() { printf '%s\n' "$2" >&2; exit 2; }; ralph_pass() { :; }; }
for h in "$root"/.claude/hooks/project/stop/*.sh; do
  if [ ! -x "$h" ]; then
    printf 'Project Stop hook %s is not executable; run chmod +x and commit it.\n' "$h" >&2
    exit 2
  fi
  out=$(printf '%s' "$input" | "$h" 2>&1)
  code=$?
  [ "$code" -eq 2 ] && ralph_block "project-$(basename "$h" .sh)" "$out"
  [ -z "$out" ] || printf '%s\n' "$out" >&2
  ralph_pass "project-$(basename "$h" .sh)"
  [ "$code" -eq 0 ] || printf 'Project Stop hook %s exited with %s\n' "$h" "$code" >&2
done
exit 0
