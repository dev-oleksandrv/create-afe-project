#!/usr/bin/env bash
# Regenerates this repository's own template-owned files from the working tree of template/, so the
# template repository follows the rules it ships (docs/maintaining.md, section 2): the update
# command of the package in this working tree, with the recorded answers. The project block of
# AGENTS.md and every seeded or project file stay as they are; a file that the template no longer
# owns is removed.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d node_modules ] || npm ci --silent
node bin/create-afe-project.js update --defaults --allow-dirty --quiet "$@" >/dev/null
echo "== synced from template/"
