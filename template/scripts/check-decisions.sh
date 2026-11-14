#!/usr/bin/env bash
# Decision-record and merge-readiness checks, run by scripts/check.sh and by the Stop dispatcher; the
# `decisions` workflow (.github/workflows/decisions.yml) runs both kinds on every pull request.
# Integrity: a record the change adds starts as proposed, accepted, or rejected, has `scope` and
# `summary`, and takes the next free number; the index docs/decisions/README.md is fresh.
# Merge readiness: no added record is still proposed, and the pull request description has the
# sections Summary, "Acceptance and test plan", Checks, and "Open questions", the evidence of each
# acceptance item, and "Gate files" for every gate path the change touches; with the
# acceptance_check module it runs scripts/check-acceptance.sh too.
#
# Usage: scripts/check-decisions.sh [--base <ref>] [--ready [--pr-body <file>] | --classes | --gate-section]
#   --base          the branch the change goes into; by default scripts/lib/git-base.sh chooses
#                   it. The change is everything between the merge base and the working tree,
#                   untracked files included. An unknown ref is an error.
#   --ready         run the merge-readiness checks instead of the integrity checks.
#   --pr-body       the pull request description to check.
#   --classes       print "<class><TAB><path>" for every path the change touches, then the review
#                   it needs before the pull request: "review<TAB>none|one|two", and nothing else.
#   --gate-section  print the body of the "Gate files" section of the description: one line
#                   "- `<path>`" for each path of class gate the change touches, or "None".
set -uo pipefail
cd "$(dirname "$0")/.."

base= ready=0 body= classes=0 gates=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:?--base needs a ref}"; shift 2 ;;
    --ready) ready=1; shift ;;
    --classes) classes=1; shift ;;
    --gate-section) gates=1; shift ;;
    --pr-body) body="${2:?--pr-body needs a file}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
skip() { printf 'SKIP: %s\n' "$*"; }

# shellcheck source=scripts/lib/git-base.sh
. scripts/lib/git-base.sh
# shellcheck source=scripts/lib/classes.sh
. scripts/lib/classes.sh
# shellcheck source=scripts/lib/harness-conf.sh
. scripts/lib/harness-conf.sh
mb=$(resolve_base "$base") || exit 2
base="${base:-the default base}"

# Every path the change touches: changed against the merge base, deleted, or untracked.
changed_paths() {
  { git diff --name-only --no-renames "$mb"; git ls-files --others --exclude-standard; } | sort -u
}

if [ "$classes" -eq 1 ]; then
  paths=()
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    paths+=("$p")
    printf '%s\t%s\n' "$(class_of "$p")" "$p"
  done < <(changed_paths)
  printf 'review\t%s\n' "$(review_level ${paths[@]+"${paths[@]}"})"
  exit 0
fi

if [ "$gates" -eq 1 ]; then
  n=0
  while IFS= read -r p; do
    [ -n "$p" ] && [ "$(class_of "$p")" = gate ] || continue
    printf -- '- `%s`\n' "$p"
    n=$((n + 1))
  done < <(changed_paths)
  [ "$n" -gt 0 ] || echo None
  exit 0
fi

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

is_record() {
  case "$1" in docs/decisions/[0-9][0-9][0-9][0-9]-*.md) return 0 ;; esac
  return 1
}

# Changed decision records as "<status letter><TAB><path>[<TAB><new path>]"; untracked files
# count as added. A modified, deleted, or renamed record is not checked.
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
  # added before it in this change.
  local max next
  max=$(git ls-tree --name-only "$mb" docs/decisions/ | sed -n 's#^docs/decisions/\([0-9]\{4\}\)-.*#\1#p' | sort | tail -n 1)
  next=$(printf '%04d' $((10#${max:-0} + 1)))
  for q in $(printf '%s\n' ${added[@]+"${added[@]}"} | sort); do
    [ "$q" = "$p" ] && break
    next=$(printf '%04d' $((10#$next + 1)))
  done
  [ "$num" = "$next" ] || fail "$p: a new record takes number $next (highest existing plus one), got $num"
}

# Prints the lines of section "## $1" of the description $2; fails when it has no such section.
section_of() {
  tr -d '\r' < "$2" | awk -v h="## $1" '/^## / {l = $0; sub(/[[:space:]]+$/, "", l); s = (l == h); seen = seen || s; next}
                                        s {print} END {exit !seen}'
}

# Prints each top-level item of the section read from stdin on one line: a bullet or a numbered
# item with its continuation lines, or a bare "None".
items() {
  awk '/^([-*+]|[0-9]+\.) / {if (it != "") print it; it = $0; sub(/^([-*+]|[0-9]+\.) +/, "", it); next}
       /^[[:space:]]*$/ {next}
       {l = $0; sub(/^[[:space:]]+/, "", l); if (it != "") it = it " " l; else print l}
       END {if (it != "") print it}'
}

# The four sections every description has: Summary, "Acceptance and test plan", Checks, and
# "Open questions".
check_sections() {
  local s
  for s in "Summary" "Acceptance and test plan" "Checks" "Open questions"; do
    section_of "$s" "$1" > /dev/null || fail "pull request description: no '## $s' section"
  done
}

# "Acceptance and test plan": each item is "None" with its reason, or names at least one file in
# backticks, and every path in backticks exists in the working tree. A path is a backticked token
# without spaces that has a "/" or ends in a file extension that starts with a letter (`test_x.py`,
# not `v1.2.0`); a "#anchor", a "::test" suffix, or a ":line" suffix is ignored.
check_acceptance() {
  local sec item paths p n=0
  sec=$(section_of "Acceptance and test plan" "$1") || return 0
  while IFS= read -r item; do
    n=$((n + 1))
    case "$item" in
      None:*|'None ('*|'None -'*|'None, '*) continue ;;
      None|None.) fail "Acceptance: 'None' needs its reason, such as 'None: documentation only'"; continue ;;
    esac
    paths=$(printf '%s\n' "$item" | grep -o '`[^`]*`' | tr -d '`' | sed -E 's/(::|#).*$//; s/:[0-9]+$//' |
      grep -E '^([A-Za-z0-9_.@+-]+(/[A-Za-z0-9_.@+-]+)+|[A-Za-z0-9_@+-][A-Za-z0-9_.@+-]*\.[A-Za-z][A-Za-z0-9]*)$')
    if [ -z "$paths" ]; then
      fail "Acceptance item names no test file in backticks: ${item:0:100}"
      continue
    fi
    while IFS= read -r p; do
      [ -e "$p" ] || fail "Acceptance names $p, which does not exist"
    done <<< "$paths"
  done < <(printf '%s\n' "$sec" | items)
  [ "$n" -gt 0 ] || fail "pull request description: 'Acceptance' is empty; write 'None' with the reason"
}

# A small diff: a warning, never a failure, when the lines the change adds and deletes, generated
# files left out, exceed DIFF_WARN_LINES of .claude/harness.conf.
check_size() {
  local limit n
  limit=$(conf_get DIFF_WARN_LINES)
  [ -n "$limit" ] || return 0
  n=$(git diff --numstat "$mb" -- . ':(exclude).template/owned.sha256' ':(exclude).afe-answers.json' \
        ':(exclude).claude/settings.json' ':(exclude)docs/decisions/README.md' | awk '{a += $1 + $2} END {print a + 0}')
  n=$((n + $(git ls-files -z --others --exclude-standard | xargs -0 cat 2>/dev/null | wc -l | tr -d ' ')))
  [ "$n" -le "$limit" ] || echo "WARNING: the change has $n changed lines, more than DIFF_WARN_LINES ($limit); split it, or say in the description why it is one change"
}

# "Gate files": names every path of class gate the change touches; prints them. The output of
# --gate-section, pasted as the body of the section, satisfies it.
check_gate_files() {
  local sec p
  sec=$(section_of "Gate files" "$1") || sec=
  while IFS= read -r p; do
    [ -n "$p" ] && [ "$(class_of "$p")" = gate ] || continue
    echo "class gate, reviewed after the merge: $p"
    printf '%s\n' "$sec" | grep -q -F -- "$p" ||
      fail "$p: class gate; list it under 'Gate files' (scripts/check-decisions.sh --gate-section prints the section)"
  done < <(changed_paths)
}

if [ "$ready" -eq 0 ]; then
  echo "== decision records: changes against $base"
  [ -n "$changes" ] || skip "no decision record changed"
  while IFS=$'\t' read -r st p1 p2; do
    [ -n "$st" ] || continue
    case "$st" in
      A) is_record "$p1" && check_added "$p1" ;;
      C*) is_record "$p2" && check_added "$p2" ;;
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
      fail "$p: still 'proposed'; the owner accepts or rejects it before the merge"
  done
  echo "== merge readiness: pull request description"
  if [ -n "$body" ]; then
    check_sections "$body"
    check_acceptance "$body"
    check_gate_files "$body"
    check_size
    if [ -x scripts/check-acceptance.sh ]; then
      scripts/check-acceptance.sh --pr-body "$body" || fail "scripts/check-acceptance.sh failed (above)"
    fi
  else
    skip "no pull request description given (--pr-body)"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "== decision checks failed: $failures"
  exit 1
fi
echo "== decision checks passed (skipped checks listed above)"
