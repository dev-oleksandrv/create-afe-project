#!/usr/bin/env bash
# Documentation checks, run by scripts/check.sh and by the Stop dispatcher: markdownlint-cli2 with the
# configuration file .markdownlint-cli2.jsonc, then scripts/check-links.mjs (links, and the
# backticked code paths of docs/ and AGENTS.md). Requires Node.js (node and npx). Both run even
# when the first fails; the exit code is that of the first failing one, else 3 when a tool is
# missing, else 0.
#
# Usage: scripts/check-docs.sh [file ...]
#   With files: lint and link-check only those of them that are existing Markdown files; a
#   relative path is relative to the current directory. Without: every Markdown file.
set -euo pipefail
caller=$PWD
cd "$(dirname "$0")/.."
root=$PWD

# A missing tool is not a failed check: exit 3, which the Stop dispatcher reports without blocking.
command -v node >/dev/null || { echo "MISSING TOOL: node (see README.md, Checks)"; exit 3; }

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

lint_code=0 links_code=0
echo "== markdownlint-cli2"
if ! command -v npx >/dev/null; then
  echo "MISSING TOOL: npx (see README.md, Checks)"
  lint_code=3
elif [ "${#files[@]}" -gt 0 ]; then
  # --no-globs: only the files given; ':' makes each one a literal path, not a glob.
  lint=()
  for f in "${files[@]}"; do lint+=(":$f"); done
  npx --yes markdownlint-cli2@0.24.0 --no-globs "${lint[@]}" || lint_code=$?
else
  npx --yes markdownlint-cli2@0.24.0 || lint_code=$?
fi

echo "== links"
node scripts/check-links.mjs ${files[@]+"${files[@]}"} || links_code=$?

for code in "$lint_code" "$links_code"; do
  if [ "$code" -ne 0 ] && [ "$code" -ne 3 ]; then
    echo "== documentation checks failed"
    exit "$code"
  fi
done
[ "$lint_code" -eq 0 ] && [ "$links_code" -eq 0 ] || exit 3
echo "== documentation checks passed"
