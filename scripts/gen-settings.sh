#!/usr/bin/env bash
# Generates .claude/settings.json (docs/documentation-rules.md, section 9) from the template's
# .claude/settings.template.json and the project's .claude/settings.project.json: objects merge
# key by key, arrays are joined without duplicates (the template's entries first), and for any
# other value the project's wins. The project's top-level "remove" holds entries to take out of
# the template's arrays, such as {"remove": {"permissions": {"deny": ["Read(**/.env.*)"]}}}.
# Claude Code reads only the generated file.
#
# Usage: scripts/gen-settings.sh [--check]
#   --check  write nothing; fail when .claude/settings.json differs from the merge.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v jq >/dev/null || { echo "gen-settings: jq is required" >&2; exit 2; }

project=.claude/settings.project.json
[ -f "$project" ] || project=/dev/null
merged=$(jq -n --slurpfile t .claude/settings.template.json --slurpfile p "$project" '
  def merge(a; b):
    if (a | type) == "object" and (b | type) == "object" then
      reduce ((a + b) | keys_unsorted[]) as $k ({};
        .[$k] = (if (a | has($k)) and (b | has($k)) then merge(a[$k]; b[$k])
                 elif (b | has($k)) then b[$k] else a[$k] end))
    elif (a | type) == "array" and (b | type) == "array" then
      reduce (a + b)[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end)
    else b end;
  def drop(a; r):
    if (a | type) == "object" and (r | type) == "object" then
      reduce (r | keys_unsorted[]) as $k (a; if has($k) then .[$k] = drop(.[$k]; r[$k]) else . end)
    elif (a | type) == "array" and (r | type) == "array" then a - r
    else a end;
  ($p[0] // {}) as $proj | drop(merge($t[0]; $proj | del(.remove)); $proj.remove // {})')

if [ "${1:-}" = --check ]; then
  [ -f .claude/settings.json ] && [ "$(jq -S . .claude/settings.json)" = "$(printf '%s' "$merged" | jq -S .)" ] || {
    echo "FAIL: .claude/settings.json is missing or stale; run scripts/gen-settings.sh"
    exit 1
  }
  exit 0
fi
printf '%s\n' "$merged" > .claude/settings.json
