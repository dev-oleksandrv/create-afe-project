#!/usr/bin/env bash
# Aggregates the "Metrics" tables of merged pull requests (docs/contributing.md, section 3): the
# findings of each sensor by class and how they were answered; the first-pass result of
# scripts/check.sh; Ralph iterations, Santa rounds, owner interventions, and files outside the
# scope, each with its median and maximum, since a distribution says more than a sum; the
# regression rate (pull requests that repair another's behaviour); and the time from opening to
# merge, which gh reports for every pull request. It measures which rules and checks earn their
# keep, so that one that never fires can be proposed for removal. Only table rows inside
# "## Metrics" are read; a pull request without that section counts for the time to merge only.
# Needs the GitHub CLI (`gh`, signed in) and jq.
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

json=$(gh pr list --state merged --limit "$limit" --json number,createdAt,mergedAt,body ${repo[@]+"${repo[@]}"}) ||
  { echo "pr-metrics: gh pr list failed" >&2; exit 2; }
listed=$(printf '%s' "$json" | jq 'length')
outside=$(printf '%s' "$json" | jq --arg since "$since" '[.[] | select(.mergedAt < $since)] | length')
sep=$(printf '\037')
printf '%s' "$json" |
  jq -r --arg since "$since" --arg sep "$sep" '.[] | select(.mergedAt >= $since) |
    ($sep + "PR \(.number) \(((.mergedAt | fromdateiso8601) - ((.createdAt // .mergedAt) | fromdateiso8601)) / 3600)"),
    ((.body // "") | gsub("\r"; ""))' |
  awk -F'|' -v sep="$sep" -v since="${since:-the first listed}" '
    function add(name, v) { cnt[name]++; val[name, cnt[name]] = v + 0; sum[name] += v }
    function stats(name,   i, j, t, n, a) {
      n = cnt[name]; if (!n) return "none"
      for (i = 1; i <= n; i++) a[i] = val[name, i]
      for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t }
      return sprintf("total %g, median %g, max %g, in %d pull requests", sum[name], (n % 2 ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2), a[n], n)
    }
    index($0, sep "PR ") == 1 { prs++; insec = 0; split(substr($0, length(sep) + 4), p, " "); add("hours to merge", sprintf("%.1f", p[2])); next }
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
        if (cell[1] == "First check.sh") { if (cell[2] ~ /^pass/) first_pass++; first_n++ }
        else if (cell[1] == "Regression of") { reg_n++; if (cell[2] !~ /^none/) reg++ }
        else if (cell[1] ~ /^(Ralph iterations|Santa rounds|Owner interventions|Files outside the scope)$/) add(tolower(cell[1]), cell[2])
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
      printf "regression rate: %d of %d pull requests repair another one\n", reg, reg_n
      split("ralph iterations|santa rounds|owner interventions|files outside the scope|hours to merge", names, "|")
      for (i = 1; i <= 5; i++) printf "%s: %s\n", names[i], stats(names[i])
      for (i = 1; i <= ns; i++) if (S[sensors[i]] == 0) quiet = quiet (quiet == "" ? "" : ", ") sensors[i]
      printf "== sensors without a finding in the period: %s\n", (quiet == "" ? "none" : quiet)
    }'
if [ "$listed" -ge "$limit" ] && [ "$outside" -eq 0 ]; then
  echo "WARNING: gh listed $listed pull requests, the --limit, all in the period; older ones in the period may be missing. Raise --limit."
fi
