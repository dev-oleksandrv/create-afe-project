#!/usr/bin/env bash
# PostToolUse hook (Edit, Write, MultiEdit): the check after every edit. It runs the project's fast
# per-file check, CHECK_EDIT of .claude/harness.conf, with the changed file as its last argument,
# and sends a failure back to the agent in the same session (exit 2), before the Stop hook and CI.
# The file is judged by the generated project that holds it (scripts/lib/root.sh), so a file in
# any worktree of the repository runs that worktree's CHECK_EDIT from its root, with the path
# relative to it, and a file in a nested repository without the harness, that of the project. CHECK_EDIT_GLOBS (shell globs separated by spaces, * also matches /) limits it to matching
# files; empty: every file. A relative path is resolved against the input's cwd. An empty
# CHECK_EDIT, a file outside any generated project, or a deleted file runs nothing. Keep the
# command to seconds: it runs after every edit.
# Not in GitHub Actions: claude-code-action restores .claude/ from the base branch there, but the
# scripts this hook runs or sources stay at the pull request's head, next to the review job's
# credentials.
[ -z "${GITHUB_ACTIONS:-}" ] || exit 0
set -uo pipefail
lib=$(cd "$(dirname "$0")/../../scripts/lib" 2>/dev/null && pwd) || exit 0
# shellcheck source=scripts/lib/root.sh
. "$lib/root.sh" 2>/dev/null || exit 0
{ IFS= read -r -d '' file; IFS= read -r -d '' cwd; } < <(node "$lib/json.mjs" fields tool_input.file_path cwd 2>/dev/null)
[ -n "${file:-}" ] || exit 0
# A relative path is relative to the session's working directory, which the input names; without
# one, to the session's project.
[ -n "${cwd:-}" ] && [ -d "$cwd" ] || cwd=${CLAUDE_PROJECT_DIR:-$PWD}
case "$file" in /*) ;; *) file="$cwd/$file" ;; esac
[ -f "$file" ] || exit 0
root=$(resolve_root "$cwd" "$file") || exit 0
cd "$root" || exit 0
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh 2>/dev/null || exit 0
cmd=$(conf_get CHECK_EDIT)
[ -n "$cmd" ] || exit 0
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

out=$(bash -c "$cmd \"\$1\"" check-edit "$rel" 2>&1 < /dev/null)
code=$?
[ "$code" -eq 0 ] && exit 0
printf 'CHECK_EDIT failed on %s (exit %s); fix it before you go on:\n%s\n' "$rel" "$code" "$(printf '%s\n' "$out" | tail -n 40)" >&2
exit 2
