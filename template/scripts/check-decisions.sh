#!/usr/bin/env bash
# Decision-record and merge-readiness checks (docs/documentation-rules.md, sections 5 and 7), run
# by scripts/check.sh. The Stop hook .claude/hooks/stop-check-decisions.sh runs the integrity
# checks; the `decisions` workflow
# (.github/workflows/decisions.yml) runs both kinds on every pull request. The integrity checks
# also require `scope`, `summary`, and the next free number in new records, and a fresh index.
#
# Usage: scripts/check-decisions.sh [--base <ref>] [--ready [--pr-body <file>]]
#   --base     the branch the change goes into; by default scripts/lib/git-base.sh chooses it.
#              The change is everything between the merge base and the working tree, untracked
#              files included. An unknown ref is an error.
#   --ready    run the merge-readiness checks instead of the integrity checks.
#   --pr-body  the pull request description to check (docs/contributing.md, section 3).
set -uo pipefail
cd "$(dirname "$0")/.."

base= ready=0 body=
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:?--base needs a ref}"; shift 2 ;;
    --ready) ready=1; shift ;;
    --pr-body) body="${2:?--pr-body needs a file}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
skip() { printf 'SKIP: %s\n' "$*"; }

# shellcheck source=scripts/lib/git-base.sh
. scripts/lib/git-base.sh
mb=$(resolve_base "$base") || exit 2
base="${base:-the default base}"

# Prints the front-matter status of the record read from stdin.
status_of() {
  tr -d '\r' | awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
       NR>1 && /^status:/ {sub(/^status:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); gsub(/^["\047]|["\047]$/, ""); print; exit}'
}

# True when the front matter of the record read from stdin has a non-empty field $1.
has_field() {
  tr -d '\r' | awk -v k="$1" 'NR==1 && $0!="---" {exit 1} NR>1 && $0=="---" {exit 1}
       NR>1 && index($0, k ":")==1 {v = substr($0, length(k) + 2); gsub(/[[:space:]"\047]/, "", v)
         done = 1; exit (v == "" || v == "[]")}
       END {if (!done) exit 1}'
}

# Prints the record read from stdin without its front-matter status line.
without_status() {
  awk 'NR==1 && $0=="---" {fm=1; print; next}
       fm && $0=="---" {fm=0}
       !(fm && /^status:/) {print}'
}

is_record() {
  case "$1" in docs/decisions/[0-9][0-9][0-9][0-9]-*.md) return 0 ;; esac
  return 1
}

# Changed decision records as "<status letter><TAB><path>[<TAB><new path>]"; untracked files
# count as added. The template and other files in docs/decisions/ are the protect hook's concern.
changes=$( {
  git diff --name-status -M "$mb" -- docs/decisions/
  git ls-files --others --exclude-standard -- docs/decisions/ | awk '{print "A\t" $0}'
} )
added=()
while IFS=$'\t' read -r st p1 p2; do
  [ -n "$st" ] || continue
  case "$st" in
    A) is_record "$p1" && added+=("$p1") ;;
    C*) is_record "$p2" && added+=("$p2") ;;
  esac
done <<< "$changes"

# True when the record numbered $1 is added by the change.
added_number() {
  local p
  for p in ${added[@]+"${added[@]}"}; do
    case "$p" in "docs/decisions/$1-"*) return 0 ;; esac
  done
  return 1
}

check_added() {
  local p="$1" status num
  status=$(status_of < "$p")
  case "$status" in
    proposed|accepted|rejected) ;;
    *) fail "$p: a new record starts as 'proposed', 'accepted', or 'rejected', got '${status:-none}'" ;;
  esac
  has_field scope < "$p" || fail "$p: front matter has no 'scope' (adr-template.md)"
  has_field summary < "$p" || fail "$p: front matter has no 'summary' (adr-template.md)"
  num=$(basename "$p" | cut -c1-4)
  set -- docs/decisions/"$num"-*.md
  [ "$#" -eq 1 ] || fail "$p: number $num is used by $# records"
  # A new record takes the highest number on the base branch plus one, counting the records
  # added before it in this change (documentation-rules.md, section 5).
  local max next
  max=$(git ls-tree --name-only "$mb" docs/decisions/ | sed -n 's#^docs/decisions/\([0-9]\{4\}\)-.*#\1#p' | sort | tail -n 1)
  next=$(printf '%04d' $((10#${max:-0} + 1)))
  for q in $(printf '%s\n' ${added[@]+"${added[@]}"} | sort); do
    [ "$q" = "$p" ] && break
    next=$(printf '%04d' $((10#$next + 1)))
  done
  [ "$num" = "$next" ] || fail "$p: a new record takes number $next (highest existing plus one), got $num"
}

check_modified() {
  local p="$1" old new os ns
  old=$(git show "$mb:$p")
  new=$(cat "$p")
  if [ "$(printf '%s\n' "$old" | without_status)" != "$(printf '%s\n' "$new" | without_status)" ]; then
    fail "$p: exists on $base and changed beyond its status line; reject it and add a new record instead (documentation-rules.md, section 5)"
  fi
  os=$(printf '%s\n' "$old" | status_of)
  ns=$(printf '%s\n' "$new" | status_of)
  case "$os -> $ns" in
    "proposed -> accepted"|"proposed -> rejected"|"accepted -> deprecated") ;;
    "accepted -> superseded by ADR-"[0-9][0-9][0-9][0-9])
      added_number "${ns##*ADR-}" ||
        fail "$p: superseded by ${ns##* }, which this change does not add" ;;
    *) fail "$p: status '$os' -> '$ns' is not a transition of documentation-rules.md, section 3" ;;
  esac
}

# A pull request description, file $1: every item under "Assumptions and open questions" is
# "None" or carries one of the labels of docs/contributing.md, section 3.
check_body() {
  local section items=0 line item doc
  section=$(tr -d '\r' < "$1" | awk '/^## /{in_s = ($0 ~ /^## Assumptions and open questions[[:space:]]*$/); seen = seen || in_s; next}
                                    in_s {print} END {exit !seen}') || {
    fail "pull request description: no '## Assumptions and open questions' section"
    return
  }
  while IFS= read -r line; do
    indented=0
    case "$line" in [[:space:]]*) indented=1 ;; esac
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      None|None.) items=$((items + 1)); continue ;;
      "- "*|"* "*|"+ "*) item="${line#??}" ;;
      [0-9]". "*|[0-9][0-9]". "*) item="${line#*. }" ;;
      *) continue ;;
    esac
    # Labels are written as label: or `label:` or `label`:.
    item=$(printf '%s' "$item" | sed -E 's/^`([a-z]+):?`:?/\1:/')
    # An indented bullet without a label is a detail of the item above it.
    if [ "$indented" = 1 ]; then
      case "$item" in blocking:*|recorded:*|assumption:*) ;; *) continue ;; esac
    fi
    items=$((items + 1))
    case "$item" in
      None|None.|assumption:*) ;;
      blocking:*) fail "blocking item still open: ${item:0:100}" ;;
      recorded:*)
        doc=$(printf '%s' "$item" | grep -o -E 'docs/[A-Za-z0-9_./-]+\.md' | head -n 1)
        if [ -z "$doc" ]; then
          fail "recorded item names no owner document (docs/...md): ${item:0:100}"
        elif [ ! -f "$doc" ]; then
          fail "recorded item names $doc, which does not exist"
        fi ;;
      *) fail "item labelled neither 'blocking:', 'recorded:', nor 'assumption:': ${item:0:100}" ;;
    esac
  done <<< "$section"
  [ "$items" -gt 0 ] || fail "pull request description: 'Assumptions and open questions' is empty; write 'None'"
}

if [ "$ready" -eq 0 ]; then
  echo "== decision records: changes against $base"
  [ -n "$changes" ] || skip "no decision record changed"
  while IFS=$'\t' read -r st p1 p2; do
    [ -n "$st" ] || continue
    case "$st" in
      A) is_record "$p1" && check_added "$p1" ;;
      C*) is_record "$p2" && check_added "$p2" ;;
      M|T) is_record "$p1" && check_modified "$p1" ;;
      D) is_record "$p1" && fail "$p1: exists on $base and is deleted; records are never deleted, their status changes (documentation-rules.md, section 5)" ;;
      R*) { is_record "$p1" || is_record "$p2"; } && fail "$p1: exists on $base and is renamed to $p2; records keep their file name" ;;
    esac
  done <<< "$changes"
  echo "== decision index: docs/decisions/README.md matches the records"
  scripts/gen-decisions-index.sh | cmp -s - docs/decisions/README.md ||
    fail "docs/decisions/README.md is missing or stale; run scripts/gen-decisions-index.sh > docs/decisions/README.md"
else
  echo "== merge readiness: records added by the change"
  [ "${#added[@]}" -gt 0 ] || skip "no decision record added"
  for p in ${added[@]+"${added[@]}"}; do
    [ "$(status_of < "$p")" = proposed ] &&
      fail "$p: still 'proposed'; the owner accepts or rejects it before the merge (docs/contributing.md, section 3)"
  done
  echo "== merge readiness: pull request description"
  if [ -n "$body" ]; then
    check_body "$body"
  else
    skip "no pull request description given (--pr-body)"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "== decision checks failed: $failures"
  exit 1
fi
echo "== decision checks passed (skipped checks listed above)"
