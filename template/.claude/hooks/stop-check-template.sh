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
if out=$(scripts/check-template.sh 2>&1); then
  exit 0
fi
printf 'Template checks failed; restore the template-owned files before finishing (docs/documentation-rules.md, section 9):\n%s\n' "$out" >&2
exit 2
