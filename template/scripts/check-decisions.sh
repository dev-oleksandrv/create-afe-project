#!/usr/bin/env bash
# Decision-record and merge-readiness checks (docs/documentation-rules.md, sections 5, 7, and 8),
# run by scripts/check.sh. The Stop hook .claude/hooks/stop-check-decisions.sh runs the integrity
# checks; the `decisions` workflow (.github/workflows/decisions.yml) runs both kinds on every pull
# request. The integrity checks also require `scope`, `summary`, and the next free number in new
# records, and a fresh index. Merge readiness reads the pull request description: the labels of
# its open items, "Acceptance and test plan", "Owner decisions" for every marker the change adds,
# "Gate files" for every gate path it touches, and the "Metrics" tables (docs/contributing.md,
# section 3); with the acceptance_check module it runs scripts/check-acceptance.sh too.
#
# Usage: scripts/check-decisions.sh [--base <ref>] [--ready [--pr-body <file>] | --classes]
#   --base     the branch the change goes into; by default scripts/lib/git-base.sh chooses it.
#              The change is everything between the merge base and the working tree, untracked
#              files included. An unknown ref is an error.
#   --ready    run the merge-readiness checks instead of the integrity checks.
#   --pr-body  the pull request description to check (docs/contributing.md, section 3).
#   --classes  print "<class><TAB><path>" for every path the change touches, then the review it
#              needs before the pull request: "review<TAB>none|one|santa" (documentation-rules.md,
#              section 8), and nothing else.
set -uo pipefail
cd "$(dirname "$0")/.."

base= ready=0 body= classes=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:?--base needs a ref}"; shift 2 ;;
    --ready) ready=1; shift ;;
    --classes) classes=1; shift ;;
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
    printf '%s\t%s\n' "$(class_of "$p" "$mb")" "$p"
  done < <(changed_paths)
  printf 'review\t%s\n' "$(review_level "$mb" ${paths[@]+"${paths[@]}"})"
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
      case "$item" in blocking:*|recorded:*|assumption:*|limit:*) ;; *) continue ;; esac
    fi
    items=$((items + 1))
    case "$item" in
      None|None.|assumption:*|limit:*) ;;
      blocking:*) fail "blocking item still open: ${item:0:100}" ;;
      recorded:*)
        doc=$(printf '%s' "$item" | grep -o -E 'docs/[A-Za-z0-9_./-]+\.md' | head -n 1)
        if [ -z "$doc" ]; then
          fail "recorded item names no owner document (docs/...md): ${item:0:100}"
        elif [ ! -f "$doc" ]; then
          fail "recorded item names $doc, which does not exist"
        fi ;;
      *) fail "item labelled neither 'blocking:', 'recorded:', 'assumption:', nor 'limit:': ${item:0:100}" ;;
    esac
  done <<< "$section"
  [ "$items" -gt 0 ] || fail "pull request description: 'Assumptions and open questions' is empty; write 'None'"
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

# "Acceptance and test plan": each item is "None" with its reason, or names at least one file in
# backticks, and every path in backticks exists in the working tree. A path is a backticked token
# without spaces that has a "/" or ends in a file extension that starts with a letter (`test_x.py`,
# not `v1.2.0`); a "#anchor", a "::test" suffix, or a ":line" suffix is ignored.
check_acceptance() {
  local sec item paths p n=0
  sec=$(section_of "Acceptance and test plan" "$1") || {
    fail "pull request description: no '## Acceptance and test plan' section (docs/contributing.md, section 3)"
    return
  }
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

# Prints the rows of the Markdown tables read from stdin, one per line: the number of cells, then
# the cells, trimmed, separated by tabs. A row starts and ends with "|".
table_rows() {
  awk -F'|' '/^[[:space:]]*\|/ {n = 0; out = ""
    for (i = 2; i < NF; i++) {c = $i; gsub(/^[ \t]+|[ \t]+$/, "", c); out = out "\t" c; n++}
    print n out}'
}

# "Metrics": the two tables of docs/contributing.md, section 3. A sensor row has six cells: the
# sensor, the class (blocker or suggestion), and the numbers found, fixed, limit, and declined,
# which add up; a blocker is never a limit. The measure table has each measure once: First
# check.sh (pass or fail), and Ralph iterations, Santa rounds, Owner interventions, and Files
# outside the scope, each a number, optionally followed by details.
check_metrics() {
  local sec n a b c d e f m measures=
  sec=$(section_of Metrics "$1") || {
    fail "pull request description: no '## Metrics' section (docs/contributing.md, section 3)"
    return
  }
  while IFS=$'\t' read -r n a b c d e f; do
    case "$a" in Sensor|Measure|''|:-*|-*) continue ;; esac
    if [ "$n" = 6 ]; then
      case "$b" in blocker|suggestion) ;; *) fail "Metrics: $a: class '$b' is neither blocker nor suggestion"; continue ;; esac
      for m in "$c" "$d" "$e" "$f"; do
        case "$m" in ''|*[!0-9]*) fail "Metrics: $a $b: '$m' is not a number"; continue 2 ;; esac
      done
      [ "$c" -eq $((d + e + f)) ] ||
        fail "Metrics: $a counts $c $b findings and answers $((d + e + f)); each finding is answered once"
      [ "$b" != blocker ] || [ "$e" -eq 0 ] || fail "Metrics: $a: a blocker is fixed or declined, never a limit"
    elif [ "$n" = 2 ]; then
      case "$a:$b" in
        'First check.sh:pass'*|'First check.sh:fail'*) ;;
        'Ralph iterations:'[0-9]*|'Santa rounds:'[0-9]*|'Owner interventions:'[0-9]*|'Files outside the scope:'[0-9]*) ;;
        *) fail "Metrics: measure '$a' with value '$b' is outside the forms of docs/contributing.md, section 3"; continue ;;
      esac
      case "$measures|" in *"|$a|"*) fail "Metrics: measure '$a' appears twice" ;; esac
      measures="$measures|$a"
    else
      fail "Metrics: a table row with $n cells; sensor rows have 6, measure rows 2"
    fi
  done < <(printf '%s\n' "$sec" | table_rows)
  for m in 'First check.sh' 'Ralph iterations' 'Santa rounds' 'Owner interventions' 'Files outside the scope'; do
    case "$measures|" in *"|$m|"*) ;; *) fail "Metrics: no '$m' row" ;; esac
  done
}

# Prints the path of the Markdown file of every `Decided by the owner, YYYY-MM-DD` marker the
# change adds, once per marker: added lines of the diff against the merge base, and untracked
# files. Markers live in owner documents, so other files, such as tests, are not read.
added_markers() {
  local re='Decided by the owner, [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' f n
  git diff --no-renames -U0 "$mb" -- '*.md' | awk -v re="$re" '/^\+\+\+ / {p = $2; sub(/^b\//, "", p); next}
    /^\+/ && p != "/dev/null" {n = gsub(re, "&"); for (i = 0; i < n; i++) print p}'
  while IFS= read -r -d '' f; do
    n=$(grep -o -E "$re" "$f" 2>/dev/null | wc -l | tr -d ' ')
    while [ "${n:-0}" -gt 0 ]; do printf '%s\n' "$f"; n=$((n - 1)); done
  done < <(git ls-files -z --others --exclude-standard -- '*.md')
}

# "Owner decisions": each file names as many items as the markers the change adds to it.
check_markers() {
  local markers sec need f have
  markers=$(added_markers | sort | uniq -c)
  [ -n "$markers" ] || return 0
  sec=$(section_of "Owner decisions" "$1") || sec=
  while read -r need f; do
    have=$(printf '%s\n' "$sec" | items | grep -c -F -- "$f")
    [ "$have" -ge "$need" ] ||
      fail "$f: the change adds $need 'Decided by the owner' marker(s) and 'Owner decisions' names the file in $have item(s) (docs/contributing.md, section 3)"
  done <<< "$markers"
}

# "Gate files": names every path of class gate the change touches; prints them.
check_gate_files() {
  local sec p
  sec=$(section_of "Gate files" "$1") || sec=
  while IFS= read -r p; do
    [ -n "$p" ] && [ "$(class_of "$p" "$mb")" = gate ] || continue
    echo "class gate, reviewed after the merge: $p"
    printf '%s\n' "$sec" | grep -q -F -- "$p" ||
      fail "$p: class gate (documentation-rules.md, section 8); list it under 'Gate files'"
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
    check_acceptance "$body"
    check_markers "$body"
    check_gate_files "$body"
    check_metrics "$body"
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
