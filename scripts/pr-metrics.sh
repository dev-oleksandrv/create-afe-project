#!/usr/bin/env bash
# Aggregates the "Metrics" tables of merged pull requests (docs/contributing.md, section 3): the
# findings of each sensor by class and how they were answered, the first-pass result of
# scripts/check.sh, Ralph iterations, Santa rounds, owner interventions, and files outside the
# scope. It measures which rules and checks earn their keep, so that one that never fires can be
# proposed for removal. Only table rows inside "## Metrics" are read; a pull request without that
# section is counted, not read. Needs the GitHub CLI (`gh`, signed in) and jq.
#
# Usage: scripts/pr-metrics.sh [--since YYYY-MM-DD] [--limit N] [--repo owner/name]
#   --since  only pull requests merged on or after this date; default: all that gh lists
#   --limit  how many merged pull requests gh lists, newest first; default 500. When all of them
#            are in the period, older ones may be missing, and the script says so.
#   --repo   the repository; default: the one of the current directory
set -uo pipefail

since= limit=500 repo=()
while [ $# -gt 0 ]; do
  case "$1" in
    --since) since="${2:?--since needs a date}"; shift 2 ;;
    --limit) limit="${2:?--limit needs a number}"; shift 2 ;;
    --repo) repo=(--repo "${2:?--repo needs owner/name}"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
command -v gh >/dev/null || { echo "pr-metrics: the GitHub CLI gh is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "pr-metrics: jq is required" >&2; exit 2; }

json=$(gh pr list --state merged --limit "$limit" --json number,mergedAt,body ${repo[@]+"${repo[@]}"}) ||
  { echo "pr-metrics: gh pr list failed" >&2; exit 2; }
listed=$(printf '%s' "$json" | jq 'length')
outside=$(printf '%s' "$json" | jq --arg since "$since" '[.[] | select(.mergedAt < $since)] | length')
sep=$(printf '\037')
printf '%s' "$json" |
  jq -r --arg since "$since" --arg sep "$sep" \
    '.[] | select(.mergedAt >= $since) | ($sep + "PR \(.number)"), ((.body // "") | gsub("\r"; ""))' |
  awk -F'|' -v sep="$sep" -v since="${since:-the first listed}" '
    index($0, sep "PR ") == 1 { prs++; insec = 0; next }
    /^## / { l = $0; sub(/[ \t]+$/, "", l); insec = (l == "## Metrics"); if (insec && !(prs in withm)) { withm[prs] = 1; nwith++ }; next }
    !insec || !/^[ \t]*\|/ { next }
    {
      n = 0
      for (i = 2; i < NF; i++) { c = $i; gsub(/^[ \t]+|[ \t]+$/, "", c); cell[++n] = c }
      if (cell[1] == "Sensor" || cell[1] == "Measure" || cell[1] ~ /^:?-/) next
      if (n == 6 && cell[2] ~ /^(blocker|suggestion)$/) {
        k = cell[1] SUBSEP cell[2]
        if (!(k in P)) order[++nk] = k
        F[k] += cell[3]; X[k] += cell[4]; L[k] += cell[5]; D[k] += cell[6]; P[k]++
        S[cell[1]] += cell[3]; if (!(cell[1] in seen)) { seen[cell[1]] = 1; sensors[++ns] = cell[1] }
      } else if (n == 2) {
        v = cell[2] + 0
        if (cell[1] == "First check.sh") { if (cell[2] ~ /^pass/) first_pass++; first_n++ }
        else if (cell[1] == "Ralph iterations") { ralph += v; ralph_n++ }
        else if (cell[1] == "Santa rounds") { santa += v; if (v > 0) santa_n++ }
        else if (cell[1] == "Owner interventions") { oi += v; if (v > 0) oi_n++ }
        else if (cell[1] == "Files outside the scope") { fo += v; if (v > 0) fo_n++ }
      }
    }
    END {
      printf "== merged pull requests since %s: %d, with a Metrics section: %d\n", since, prs, nwith
      printf "%-24s %-10s %6s %6s %6s %8s %4s\n", "sensor", "class", "found", "fixed", "limit", "declined", "PRs"
      for (i = 1; i <= nk; i++) {
        split(order[i], kk, SUBSEP)
        printf "%-24s %-10s %6d %6d %6d %8d %4d\n", kk[1], kk[2], F[order[i]], X[order[i]], L[order[i]], D[order[i]], P[order[i]]
      }
      printf "first check.sh passed: %d of %d pull requests\n", first_pass, first_n
      printf "Ralph iterations: %d in %d pull requests\n", ralph, ralph_n
      printf "Santa rounds: %d in %d pull requests\n", santa, santa_n
      printf "owner interventions: %d in %d pull requests\n", oi, oi_n
      printf "files outside the scope: %d in %d pull requests\n", fo, fo_n
      for (i = 1; i <= ns; i++) if (S[sensors[i]] == 0) quiet = quiet (quiet == "" ? "" : ", ") sensors[i]
      printf "== sensors without a finding in the period: %s\n", (quiet == "" ? "none" : quiet)
    }'
if [ "$listed" -ge "$limit" ] && [ "$outside" -eq 0 ]; then
  echo "WARNING: gh listed $listed pull requests, the --limit, all in the period; older ones in the period may be missing. Raise --limit."
fi
