#!/usr/bin/env bash
# Documentation checks, run by scripts/check.sh (AGENTS.md, section 6).
# CI (.github/workflows/docs.yml) runs the same tools through their official actions
# with the same configuration file, .markdownlint-cli2.jsonc, and the same link check.
# Requires Node.js (node and npx).
set -euo pipefail
cd "$(dirname "$0")/.."

# A missing tool is not a failed check: exit 3, which the Stop hook reports without blocking.
for tool in node npx; do
  command -v "$tool" >/dev/null || { echo "MISSING TOOL: $tool (see README.md, Checks)"; exit 3; }
done

echo "== markdownlint-cli2"
npx --yes markdownlint-cli2@0.24.0

echo "== links"
node scripts/check-links.mjs

echo "== documentation checks passed"
