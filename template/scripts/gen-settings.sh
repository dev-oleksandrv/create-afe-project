#!/usr/bin/env bash
# Generates .claude/settings.json from the template's .claude/settings.template.json and the
# project's .claude/settings.project.json: objects merge key by key, arrays are joined without
# duplicates (the template's entries first), and for any other value the project's wins. The
# project's top-level "remove" holds entries to take out of the template's arrays, such as
# {"remove": {"permissions": {"deny": ["Read(**/.env.*)"]}}}. Claude Code reads only the generated
# file.
#
# Usage: scripts/gen-settings.sh [--check]
#   --check  write nothing; fail when .claude/settings.json differs from the merge.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v node >/dev/null || { echo "gen-settings: Node.js is required" >&2; exit 2; }
exec node scripts/lib/json.mjs settings ${1:+"$1"}
