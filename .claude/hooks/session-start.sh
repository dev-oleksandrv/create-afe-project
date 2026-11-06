#!/usr/bin/env bash
# SessionStart hook: prints the local state of the work in progress, so that a new, resumed, or
# compacted session starts from facts (docs/documentation-rules.md, section 7): the branch, the
# base of the change (scripts/lib/git-base.sh) and the commits ahead of it, the count of
# uncommitted and untracked files, unresolved merge conflicts, and each plan in docs/plans/ with
# its review-by date, flagged when the date is past (section 5), past ones first. At most 10 lines
# and local facts only: no network. Outside a git repository only the plans are shown. What it
# cannot determine it leaves out; it always exits 0.
# Not in GitHub Actions: claude-code-action restores .claude/ from the base branch there, but the
# scripts this hook runs or sources stay at the pull request's head, next to the review job's
# credentials (docs/documentation-rules.md, section 7).
[ -z "${GITHUB_ACTIONS:-}" ] || exit 0
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] || exit 0
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
    lines+=("unresolved merge conflicts in $conflicts files: resolve them first (docs/contributing.md, section 5)")
fi

shopt -s nullglob
plans=()
for p in docs/plans/*.md; do
  [ "$(basename "$p")" = README.md ] || plans+=("$p")
done
# SESSION_START_TODAY (YYYY-MM-DD) stands in for the clock, for the tests.
today=${SESSION_START_TODAY:-$(date +%Y-%m-%d)}
# Plans past their review-by come first, then those without one, then the rest, so the five shown
# never hide a past one; the line for the rest counts the past ones among them.
past=() undated=() ahead=()
for p in ${plans[@]+"${plans[@]}"}; do
  rb=$(awk 'NR == 1 && $0 != "---" {exit} NR > 1 && $0 == "---" {exit}
    /^review-by:/ {sub(/^review-by:[[:space:]]*/, ""); gsub(/["'\''[:space:]]/, ""); print; exit}' "$p" 2> /dev/null)
  if ! printf '%s' "$rb" | grep -q -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    undated+=("plan $p: no review-by date")
  elif [[ "$rb" < "$today" ]]; then
    past+=("plan $p: review-by $rb is past; update or delete it (docs/documentation-rules.md, section 5)")
  else
    ahead+=("plan $p: review-by $rb")
  fi
done
ordered=(${past[@]+"${past[@]}"} ${undated[@]+"${undated[@]}"} ${ahead[@]+"${ahead[@]}"})
[ "${#ordered[@]}" -eq 0 ] || for i in "${!ordered[@]}"; do
  if [ "$i" -eq 5 ]; then
    rest="and $(( ${#ordered[@]} - 5 )) more plans in docs/plans/"
    [ "${#past[@]}" -le 5 ] || rest="$rest, $(( ${#past[@]} - 5 )) of them past their review-by"
    lines+=("$rest")
    break
  fi
  lines+=("${ordered[$i]}")
done

[ "${#lines[@]}" -gt 0 ] || exit 0
echo "Local state at session start (.claude/hooks/session-start.sh):"
printf -- '- %s\n' "${lines[@]}"
exit 0
