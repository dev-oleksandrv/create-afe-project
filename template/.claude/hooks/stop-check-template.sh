#!/usr/bin/env bash
# Stop hook: Claude Code may not finish a turn while a template-owned file differs from the template
# or AGENTS.md lost its project block (docs/documentation-rules.md, section 9). Exit 2 sends the
# agent back with the check output. DOCS_GUARD=off disables it, as for the protect hook.
set -uo pipefail
[ "${DOCS_GUARD:-on}" = "off" ] && exit 0
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || exit 0
cd "$root" || exit 0
# During an unresolved merge conflict (a template update) the checks cannot pass yet; let the
# agent stop and ask instead of looping.
if [ -n "$(git ls-files -u 2>/dev/null)" ]; then
  echo "Unresolved merge conflicts: checks resume once they are resolved (docs/contributing.md, section 5)." >&2
  exit 0
fi
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || { ralph_block() { printf '%s\n' "$2" >&2; exit 2; }; ralph_pass() { :; }; }
if out=$(scripts/check-template.sh 2>&1); then
  ralph_pass template
  exit 0
fi
ralph_block template "$(printf 'Template checks failed; restore the template-owned files before finishing (docs/documentation-rules.md, section 9):\n%s' "$out")"
