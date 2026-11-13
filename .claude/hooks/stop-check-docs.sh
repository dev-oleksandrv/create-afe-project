#!/usr/bin/env bash
# Stop hook: Claude Code may not finish a turn while the documentation checks fail. Runs
# scripts/check-docs.sh only when a Markdown file differs from the base of the change
# (scripts/lib/git-base.sh), committed or not, so unrelated turns pay nothing. Exit 2 sends the
# agent back with the check output; a missing tool is reported without blocking.
# Not in GitHub Actions: claude-code-action restores .claude/ from the base branch there, but the
# scripts this hook runs or sources stay at the pull request's head, next to the review job's
# credentials (docs/documentation-rules.md, section 7).
[ -z "${GITHUB_ACTIONS:-}" ] || exit 0
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || exit 0
cd "$root" || exit 0
# During an unresolved merge conflict the checks cannot pass yet; let the
# agent stop and ask instead of looping.
if [ -n "$(git ls-files -u 2>/dev/null)" ]; then
  echo "Unresolved merge conflicts: checks resume once they are resolved (git status lists them)." >&2
  exit 0
fi
# shellcheck source=scripts/lib/git-base.sh
. scripts/lib/git-base.sh
base=$(resolve_base 2>/dev/null) || exit 0
changed=$( { git diff --name-only "$base" -- '*.md'; git ls-files --others --exclude-standard -- '*.md'; } 2>/dev/null | head -n 1)
[ -n "$changed" ] || exit 0
RALPH_SESSION=$(node scripts/lib/json.mjs get session_id none 2>/dev/null || echo none)
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || { ralph_block() { printf '%s\n' "$2" >&2; exit 2; }; ralph_pass() { :; }; }
# Keeps a failure from flooding the chat: a per-file, per-rule summary of "<path>:<line>[:<col>]
# error <RULE>/..." lines (markdownlint), then the first 10 lines of output, then a pointer.
brief() {
  printf '%s\n' "$1" | grep -v '^markdownlint-cli2 v' > "${TMPDIR:-/tmp}/stop-docs.$$"
  f="${TMPDIR:-/tmp}/stop-docs.$$"
  awk '
    $1 ~ /^[^ :]+:[0-9]+(:[0-9]+)?$/ && $2 == "error" && $3 ~ /^[A-Za-z]+[0-9]+/ {
      file = $1; sub(/:[0-9]+(:[0-9]+)?$/, "", file)
      if (!(file in nf)) { nf[file] = 1; order[++n] = file }
      key = file SUBSEP $3
      if (!(key in cnt)) { rules[file] = rules[file] (rules[file] == "" ? "" : ", ") $3; cnt[key] = 0 }
      cnt[key]++
    }
    END {
      for (i = 1; i <= n; i++) {
        file = order[i]; line = ""; m = split(rules[file], r, ", ")
        for (j = 1; j <= m; j++) line = line (j > 1 ? ", " : "") r[j] " x" cnt[file SUBSEP r[j]]
        print file ": " line
      }
    }' "$f"
  total=$(wc -l < "$f" | tr -d ' ')
  head -n 10 "$f"
  [ "$total" -le 10 ] || printf '... %s more lines\n' "$((total - 10))"
  rm -f "$f"
}
out=$(scripts/check-docs.sh 2>&1)
case $? in
  0) ralph_pass docs; exit 0 ;;
  3) printf 'Documentation checks could not run; install the missing tool:\n%s\n' "$(printf '%s\n' "$out" | head -n 10)" >&2; exit 1 ;;
esac
ralph_block docs "$(printf 'Documentation checks failed; fix them before finishing (AGENTS.md, section 6):\n%s\nFull output: scripts/check-docs.sh' "$(brief "$out")")"
