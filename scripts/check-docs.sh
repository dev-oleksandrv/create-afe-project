#!/usr/bin/env bash
# Documentation checks, run by scripts/check.sh and by the Stop dispatcher: scripts/check-links.mjs
# (links, and the backticked code paths of docs/ outside docs/decisions/ and of AGENTS.md).
# Requires Node.js. The exit code is that of the link check, or 3 when node is missing.
#
# Usage: scripts/check-docs.sh [file ...]
#   With files: check only those of them that are existing Markdown files; a relative path is
#   relative to the current directory. Without: every Markdown file.
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

echo "== links"
code=0
node scripts/check-links.mjs ${files[@]+"${files[@]}"} || code=$?
if [ "$code" -ne 0 ]; then
  echo "== documentation checks failed"
  exit "$code"
fi
echo "== documentation checks passed"
