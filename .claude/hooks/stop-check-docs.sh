#!/usr/bin/env bash
# Stop hook: Claude Code may not finish a turn while the documentation checks fail. Runs
# scripts/check-docs.sh only when a Markdown file differs from the base of the change
# (scripts/lib/git-base.sh), committed or not, so unrelated turns pay nothing. Exit 2 sends the
# agent back with the check output; a missing tool is reported without blocking.
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
# shellcheck source=scripts/lib/git-base.sh
. scripts/lib/git-base.sh
base=$(resolve_base 2>/dev/null) || exit 0
changed=$( { git diff --name-only "$base" -- '*.md'; git ls-files --others --exclude-standard -- '*.md'; } 2>/dev/null | head -n 1)
[ -n "$changed" ] || exit 0
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || { ralph_block() { printf '%s\n' "$2" >&2; exit 2; }; ralph_pass() { :; }; }
out=$(scripts/check-docs.sh 2>&1)
case $? in
  0) ralph_pass docs; exit 0 ;;
  3) printf 'Documentation checks could not run; install the missing tool:\n%s\n' "$out" >&2; exit 1 ;;
esac
ralph_block docs "$(printf 'Documentation checks failed; fix them before finishing (AGENTS.md, section 6):\n%s' "$out")"
