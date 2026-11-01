#!/usr/bin/env bash
# Protects the default branch on GitHub (AGENTS.md, section 4): changes reach it only through pull
# requests whose `docs` and `decisions` integrity checks pass, and it cannot be force-pushed or
# deleted. It creates or updates the repository ruleset "protect default branch" with the GitHub
# CLI; run it once as a repository admin, after the first push. A change of repository settings
# is an owner action: an agent runs it only on the owner's explicit instruction.
#
# Usage: scripts/protect-branch.sh [--dry-run] [--repo owner/name]
#   --dry-run  print the ruleset and change nothing
#   --repo     the repository; default: the one of the current directory
# Rulesets need a public repository, or a GitHub plan that offers them for private ones.
set -euo pipefail
cd "$(dirname "$0")/.."

dry= repo=
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --repo) repo="${2:?--repo needs owner/name}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

name="protect default branch"
ruleset=$(node -e '
  const [name] = process.argv.slice(1);
  console.log(JSON.stringify({
    name, target: "branch", enforcement: "active",
    conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
    rules: [
      { type: "deletion" },
      { type: "non_fast_forward" },
      { type: "pull_request", parameters: { required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
          require_code_owner_review: false, require_last_push_approval: false, required_review_thread_resolution: false } },
      { type: "required_status_checks", parameters: { strict_required_status_checks_policy: false,
          required_status_checks: [{ context: "check" }, { context: "integrity" }] } },
    ],
  }, null, 2));' "$name")

if [ -n "$dry" ]; then
  printf '%s\n' "$ruleset"
  exit 0
fi
command -v gh > /dev/null || { echo "protect-branch: the GitHub CLI gh is required" >&2; exit 2; }
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id" | head -n 1)
if [ -n "$id" ]; then
  printf '%s' "$ruleset" | gh api --method PUT "repos/$repo/rulesets/$id" --input - > /dev/null
  echo "== updated the ruleset \"$name\" of $repo"
else
  printf '%s' "$ruleset" | gh api --method POST "repos/$repo/rulesets" --input - > /dev/null
  echo "== created the ruleset \"$name\" of $repo"
fi
