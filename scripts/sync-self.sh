#!/usr/bin/env bash
# Regenerates this repository's own template-owned files from the working tree of template/, so the
# template repository follows the rules it ships (docs/maintaining.md, section 2). The project block
# of AGENTS.md and every seeded or project file stay as they are; a file that the template no
# longer owns is removed.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v copier >/dev/null; then
  command -v uvx >/dev/null || { echo "copier is not installed (uv tool install copier)" >&2; exit 2; }
  copier() { uvx --quiet --from 'copier>=9.4' copier "$@"; }
fi

start='<!-- project:start -->'
end='<!-- project:end -->'
[ "$(grep -c -x -F "$start" AGENTS.md)" = 1 ] && [ "$(grep -c -x -F "$end" AGENTS.md)" = 1 ] ||
  { echo "AGENTS.md needs exactly one project block before a sync" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
grep -v -E '^(_|#)' .copier-answers.yml > "$work/answers.yml"
copier copy -q --trust --defaults --vcs-ref HEAD --data-file "$work/answers.yml" . "$work/out" >/dev/null

owned() { grep -v -E '^[[:space:]]*(#|$)' "$1"; }
# Files the template owned before and owns no longer.
comm -23 <(owned .template/owned.txt | sort) <(owned "$work/out/.template/owned.txt" | sort) |
  while IFS= read -r p; do rm -f "$p"; echo "removed $p"; done

owned "$work/out/.template/owned.txt" | while IFS= read -r p; do
  mkdir -p "$(dirname "$p")"
  if [ "$p" = AGENTS.md ]; then
    awk -v s="$start" -v e="$end" '$0==s {f=1; next} $0==e {f=0} f' AGENTS.md > "$work/block"
    awk -v s="$start" -v e="$end" -v bf="$work/block" \
      '$0==s {print; while ((getline l < bf) > 0) print l; skip=1; next} $0==e {skip=0} !skip' \
      "$work/out/AGENTS.md" > "$work/AGENTS.md"
    mv "$work/AGENTS.md" AGENTS.md
  else
    cp -p "$work/out/$p" "$p"
  fi
done
scripts/gen-settings.sh
scripts/check-template.sh --write
scripts/gen-decisions-index.sh > docs/decisions/README.md
echo "== synced from template/"
