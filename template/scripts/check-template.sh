#!/usr/bin/env bash
# Template integrity (docs/documentation-rules.md, sections 2 and 9): every template-owned file
# listed in .template/owned.txt matches its hash in .template/owned.sha256, AGENTS.md contains
# exactly one project block, the rule documents stay within their line budgets, and the generated
# .claude/settings.json is current. The hash of AGENTS.md ignores the content of its project block.
#
# Usage: scripts/check-template.sh [--write]
#   --write  record the current hashes; the template runs it after `copier copy` and
#            `copier update`. Never run it to make a local edit of a template-owned file pass.
set -euo pipefail
cd "$(dirname "$0")/.."

list=.template/owned.txt
manifest=.template/owned.sha256
start='<!-- project:start -->'
end='<!-- project:end -->'

if command -v sha256sum >/dev/null; then sha() { sha256sum | cut -d' ' -f1; }
else sha() { shasum -a 256 | cut -d' ' -f1; }; fi

# Prints the content that the hash covers: AGENTS.md without the lines inside its project block.
content() {
  if [ "$1" = AGENTS.md ]; then
    awk -v s="$start" -v e="$end" '$0==s {print; skip=1; next} $0==e {skip=0} !skip' "$1"
  else
    cat "$1"
  fi
}

paths() { grep -v -E '^[[:space:]]*(#|$)' "$list"; }

if [ "${1:-}" = "--write" ]; then
  while IFS= read -r p; do
    [ -f "$p" ] || { echo "FAIL: $p is listed in $list but missing" >&2; exit 1; }
  done < <(paths)
  paths | while IFS= read -r p; do printf '%s  %s\n' "$(content "$p" | sha)" "$p"; done > "$manifest"
  echo "== template manifest written: $manifest"
  exit 0
fi

failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

echo "== template-owned files match $manifest"
[ -f "$list" ] && [ -f "$manifest" ] || { echo "FAIL: $list or $manifest is missing"; exit 1; }
while IFS= read -r p; do
  if [ ! -f "$p" ]; then
    fail "$p: template-owned file is missing"
  elif [ "$(content "$p" | sha)" != "$(awk -v p="$p" '$2==p {print $1}' "$manifest")" ]; then
    fail "$p: differs from the template; change it in the template repository and update (docs/contributing.md, section 5)"
  fi
done < <(paths)
[ "$(paths | sort)" = "$(awk '{print $2}' "$manifest" | sort)" ] ||
  fail "$manifest does not list exactly the paths of $list; it is regenerated only by a template update"

echo "== AGENTS.md has exactly one project block"
[ "$(grep -c -x -F "$start" AGENTS.md)" = 1 ] && [ "$(grep -c -x -F "$end" AGENTS.md)" = 1 ] &&
  [ "$(grep -n -x -F "$start" AGENTS.md | cut -d: -f1)" -lt "$(grep -n -x -F "$end" AGENTS.md | cut -d: -f1)" ] ||
  fail "AGENTS.md: expected one '$start' line followed by one '$end' line"

echo "== AGENTS.md: template part at most 90 lines, project block at most 10 (documentation-rules.md, section 2)"
block=$(awk -v s="$start" -v e="$end" '$0==s {f=1; next} $0==e {f=0} f' AGENTS.md | wc -l | tr -d ' ')
total=$(wc -l < AGENTS.md | tr -d ' ')
[ "$block" -le 10 ] || fail "AGENTS.md: the project block has $block lines; at most 10"
[ $((total - block)) -le 90 ] || fail "AGENTS.md: the template part has $((total - block)) lines; at most 90 (a template defect)"

echo "== rule documents within their line budgets (documentation-rules.md, section 2)"
for spec in docs/documentation-rules.md:200 docs/contributing.md:200 docs/testing-rules.md:80; do
  n=$(wc -l < "${spec%:*}" | tr -d ' ')
  [ "$n" -le "${spec##*:}" ] || fail "${spec%:*}: $n lines; at most ${spec##*:} (a template defect)"
done

echo "== .claude/settings.json is generated from the template's and the project's settings"
out=$(scripts/gen-settings.sh --check 2>&1) || fail "${out#FAIL: }"

if [ "$failures" -gt 0 ]; then
  echo "== template checks failed: $failures"
  exit 1
fi
echo "== template checks passed"
