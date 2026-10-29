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
for h in "$root"/.claude/hooks/project/stop/*.sh; do
  if [ ! -x "$h" ]; then
    printf 'Project Stop hook %s is not executable; run chmod +x and commit it.\n' "$h" >&2
    exit 2
  fi
  printf '%s' "$input" | "$h" 1>&2
  code=$?
  [ "$code" -eq 2 ] && exit 2
  [ "$code" -eq 0 ] || printf 'Project Stop hook %s exited with %s\n' "$h" "$code" >&2
done
exit 0
