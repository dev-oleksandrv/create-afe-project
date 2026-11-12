#!/usr/bin/env bash
# SessionStart hook: prints the local state of the work in progress, so that a new, resumed, or
# compacted session starts from facts: the branch, the base of the change (scripts/lib/git-base.sh)
# and the commits ahead of it, the count of uncommitted and untracked files, and unresolved merge
# conflicts, for the repository that holds the input's cwd (scripts/lib/root.sh). Local facts only:
# no network. Outside a git repository it prints nothing. What it cannot determine it leaves out;
# it always exits 0.
# Not in GitHub Actions: claude-code-action restores .claude/ from the base branch there, but the
# scripts this hook runs or sources stay at the pull request's head, next to the review job's
# credentials.
[ -z "${GITHUB_ACTIONS:-}" ] || exit 0
set -uo pipefail
lib=$(cd "$(dirname "$0")/../../scripts/lib" 2>/dev/null && pwd) || exit 0
# shellcheck source=scripts/lib/root.sh
. "$lib/root.sh" 2>/dev/null || exit 0
cwd=$(node "$lib/json.mjs" get cwd 2>/dev/null)
root=$(resolve_root "$cwd") || exit 0
cd "$root" 2>/dev/null || exit 0
lines=()

if git rev-parse --git-dir > /dev/null 2>&1; then
  if git rev-parse --verify -q HEAD > /dev/null; then
    line="branch $(git symbolic-ref --short -q HEAD || printf 'none (detached at %s)' "$(git rev-parse --short HEAD)")"
    # shellcheck source=scripts/lib/git-base.sh
    if . scripts/lib/git-base.sh 2> /dev/null && base=$(resolve_base 2> /dev/null); then
      name=
      for ref in origin/HEAD origin/main main; do
        git rev-parse --verify -q "$ref^{commit}" > /dev/null 2>&1 || continue
        [ "$(git merge-base "$ref" HEAD 2> /dev/null)" = "$base" ] || continue
        name=$(git rev-parse --abbrev-ref "$ref" 2> /dev/null || echo "$ref")
        break
      done
      ahead=$(git rev-list --count "$base..HEAD" 2> /dev/null)
      if [ -n "$name" ] && [ -n "$ahead" ]; then
        line="$line; base $name at $(git rev-parse --short "$base"), $ahead commits ahead"
      elif [ -z "$name" ]; then
        line="$line; no base branch (origin/HEAD, origin/main, main): only uncommitted changes count"
      fi
    fi
    lines+=("$line")
  fi
  if st=$(git status --porcelain --untracked-files=all 2> /dev/null); then
    untracked=$(printf '%s\n' "$st" | grep -c '^??')
    changed=$(printf '%s\n' "$st" | grep -v '^??' | grep -c .)
    lines+=("uncommitted files: $changed; untracked files: $untracked")
  fi
  conflicts=$(git ls-files -u 2> /dev/null | cut -f2 | sort -u | grep -c .)
  [ "${conflicts:-0}" -gt 0 ] &&
    lines+=("unresolved merge conflicts in $conflicts files: resolve them first (git status lists them)")
fi

[ "${#lines[@]}" -gt 0 ] || exit 0
echo "Local state at session start (.claude/hooks/session-start.sh):"
printf -- '- %s\n' "${lines[@]}"
exit 0
