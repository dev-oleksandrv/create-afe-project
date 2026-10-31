#!/usr/bin/env bash
# Stop hook: Claude Code may not finish a turn while the decision-record integrity checks of
# scripts/check-decisions.sh fail (docs/documentation-rules.md, sections 5 and 7). Merge readiness
# is not checked here: an agent legitimately stops with a `proposed` record to ask the owner. Exit 2
# sends the agent back with the check output. DOCS_GUARD=off disables it, as for the protect hook
# (docs/documentation-rules.md, section 8).
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
RALPH_SESSION=$(jq -r '.session_id // "none"' 2>/dev/null || echo none)
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || { ralph_block() { printf '%s\n' "$2" >&2; exit 2; }; ralph_pass() { :; }; }
if out=$(scripts/check-decisions.sh 2>&1); then
  ralph_pass decisions
  exit 0
fi
ralph_block decisions "$(printf 'Decision record checks failed; fix them before finishing (docs/documentation-rules.md, section 5):\n%s' "$out")"
