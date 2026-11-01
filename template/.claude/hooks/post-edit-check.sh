#!/usr/bin/env bash
# PostToolUse hook (Edit, Write, MultiEdit): the check after every edit (docs/testing-rules.md,
# section 4). It runs the project's fast per-file check, CHECK_EDIT of .claude/harness.conf, with
# the changed file as its last argument, and sends a failure back to the agent in the same
# session (exit 2), before the Stop hooks and CI. CHECK_EDIT_GLOBS (shell globs separated by
# spaces, * also matches /) limits it to matching files; empty: every file. An empty CHECK_EDIT,
# a file outside the project, or a deleted file runs nothing. Keep the command to seconds: it runs
# after every edit.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || exit 0
cd "$root" || exit 0
. scripts/lib/harness-conf.sh 2>/dev/null || exit 0
cmd=$(conf_get CHECK_EDIT)
[ -n "$cmd" ] || exit 0
file=$(node scripts/lib/json.mjs get tool_input.file_path 2>/dev/null) || exit 0
[ -n "$file" ] && [ -f "$file" ] || exit 0
root=$(pwd -P)
abs=$(cd "$(dirname "$file")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$file")") || exit 0
case "$abs" in "$root"/*) rel=${abs#"$root"/} ;; *) exit 0 ;; esac

globs=$(conf_get CHECK_EDIT_GLOBS)
if [ -n "$globs" ]; then
  match=
  set -f
  for g in $globs; do
    # shellcheck disable=SC2254
    case "$rel" in $g) match=1; break ;; esac
  done
  set +f
  [ -n "$match" ] || exit 0
fi

out=$(bash -c "$cmd \"\$1\"" check-edit "$rel" 2>&1)
code=$?
[ "$code" -eq 0 ] && exit 0
printf 'CHECK_EDIT failed on %s (exit %s); fix it before you go on:\n%s\n' "$rel" "$code" "$(printf '%s\n' "$out" | tail -n 40)" >&2
exit 2
