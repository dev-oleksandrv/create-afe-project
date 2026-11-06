#!/usr/bin/env bash
# Stop hook: Claude Code may not finish a turn while the project's fast check fails
# (docs/documentation-rules.md, section 7). Runs `scripts/env.sh fast`, the CHECK_FAST command of
# .claude/harness.conf, only when a file other than Markdown differs from the base of the change
# (scripts/lib/git-base.sh), committed or not, untracked included. It skips when CHECK_FAST is
# empty or is the default scripts/check-docs.sh, which stop-check-docs.sh already runs for
# Markdown. Exit 2 sends the agent back with the command's output, up to the Ralph cap.
set -uo pipefail
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
. scripts/lib/harness-conf.sh 2>/dev/null || exit 0
case "$(conf_get CHECK_FAST)" in
  ''|scripts/check-docs.sh) exit 0 ;;
esac
# shellcheck source=scripts/lib/git-base.sh
. scripts/lib/git-base.sh
base=$(resolve_base 2>/dev/null) || exit 0
changed=$( { git diff --name-only "$base" -- . ':(exclude)*.md'; git ls-files --others --exclude-standard -- . ':(exclude)*.md'; } 2>/dev/null | head -n 1)
[ -n "$changed" ] || exit 0
RALPH_SESSION=$(node scripts/lib/json.mjs get session_id none 2>/dev/null || echo none)
if out=$(scripts/env.sh fast 2>&1); then
  ralph_pass fast
  exit 0
fi
ralph_block fast "$(printf 'The fast check (CHECK_FAST in .claude/harness.conf) failed; fix it before finishing (AGENTS.md, section 6):\n%s' "$(printf '%s\n' "$out" | tail -n 60)")"
