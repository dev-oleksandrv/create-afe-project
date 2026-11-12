#!/usr/bin/env bash
# Documentation checks, run by scripts/check.sh and by the Stop dispatcher: markdownlint-cli2 with the
# configuration file .markdownlint-cli2.jsonc, then scripts/check-links.mjs (links, and the
# backticked code paths of docs/ and AGENTS.md). Requires Node.js (node and npx).
#
# Usage: scripts/check-docs.sh [file ...]
#   With files: lint and link-check only those of them that are existing Markdown files; a
#   relative path is relative to the current directory. Without: every Markdown file.
set -euo pipefail
caller=$PWD
cd "$(dirname "$0")/.."
root=$PWD

# A missing tool is not a failed check: exit 3, which the Stop dispatcher reports without blocking.
for tool in node npx; do
  command -v "$tool" >/dev/null || { echo "MISSING TOOL: $tool (see README.md, Checks)"; exit 3; }
done

files=()
if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    case "$f" in /*) ;; *) f="$caller/$f" ;; esac
    case "$f" in *.md) ;; *) continue ;; esac
    [ -f "$f" ] || continue
    f=$(cd "$(dirname "$f")" && pwd -P)/$(basename "$f")
    case "$f" in "$(pwd -P)"/*) f=${f#"$(pwd -P)"/} ;; "$root"/*) f=${f#"$root"/} ;; esac
    files+=("$f")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    echo "== documentation checks passed: no Markdown file among the arguments"
    exit 0
  fi
fi

echo "== markdownlint-cli2"
if [ "${#files[@]}" -gt 0 ]; then
  # --no-globs: only the files given; ':' makes each one a literal path, not a glob.
  lint=()
  for f in "${files[@]}"; do lint+=(":$f"); done
  npx --yes markdownlint-cli2@0.24.0 --no-globs "${lint[@]}"
else
  npx --yes markdownlint-cli2@0.24.0
fi

echo "== links"
node scripts/check-links.mjs ${files[@]+"${files[@]}"}

echo "== documentation checks passed"
