#!/usr/bin/env bash
# Protects the default branch on GitHub (AGENTS.md, section 4) and applies the repository settings
# the rules assume (docs/contributing.md, sections 1 and 3), with the GitHub CLI; run it once as a
# repository admin, after the first push, and again with --require-base when that applies. A change
# of repository settings is an owner action: an agent runs it only on the owner's explicit
# instruction. In this order:
# 1. Merge commits only, without squash and rebase merging, and "Automatically delete head
#    branches": these work on every plan.
# 2. Secret scanning with push protection: public repositories have them; a private one may need
#    GitHub Advanced Security, so a refusal is reported and the script goes on.
# 3. The repository ruleset "protect default branch": changes reach the default branch only through
#    pull requests merged with a merge commit whose `check` (`docs` workflow) and `integrity`
#    (`decisions` workflow) jobs pass, with --require-base also `base`, and only these: `readiness`
#    signals and AI review is a sensor; it cannot be force-pushed or deleted. Updating a ruleset
#    that requires `base` keeps it without --require-base while the fail-without-change workflow
#    exists, drops it otherwise, and says which; a ruleset it cannot read stops the run unchanged.
#    Rulesets need a public repository, or a GitHub plan that offers them for private ones;
#    without one, the rule rests on the owner and review.
#
# Usage: scripts/protect-branch.sh [--dry-run] [--repo owner/name] [--require-base]
#   --dry-run       print the settings and the ruleset as one JSON object and change nothing
#   --repo          the repository; default: the one of the current directory
#   --require-base  also require the `base` job of the fail-without-change workflow: use it once
#                   that job has passed in CI on a pull request that changes a test, not as a SKIP;
#                   the label `tests-pass-on-base` still lets a test that passes on the base through
set -euo pipefail
cd "$(dirname "$0")/.."

dry= repo= base=
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --repo) repo="${2:?--repo needs owner/name}"; shift 2 ;;
    --require-base) base=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -n "$base" ] && [ ! -f .github/workflows/fail-without-change.yml ]; then
  echo "protect-branch: --require-base needs the fail-without-change workflow, which this project does not have" >&2
  exit 2
fi

name="protect default branch"
plan() { node -e '
  const [name, base] = process.argv.slice(1);
  const checks = ["check", "integrity", ...(base ? ["base"] : [])].map((context) => ({ context }));
  console.log(JSON.stringify({
    repository: { allow_merge_commit: true, allow_squash_merge: false, allow_rebase_merge: false, delete_branch_on_merge: true },
    security: { security_and_analysis: { secret_scanning: { status: "enabled" }, secret_scanning_push_protection: { status: "enabled" } } },
    ruleset: {
      name, target: "branch", enforcement: "active",
      conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
      rules: [
        { type: "deletion" },
        { type: "non_fast_forward" },
        { type: "pull_request", parameters: { required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
            require_code_owner_review: false, require_last_push_approval: false, required_review_thread_resolution: false,
            allowed_merge_methods: ["merge"] } },
        { type: "required_status_checks", parameters: { strict_required_status_checks_policy: false,
            required_status_checks: checks } },
      ],
    },
  }, null, 2));' "$name" "$base"; }

if [ -n "$dry" ]; then
  plan
  exit 0
fi
part() { plan | node -e 'console.log(JSON.stringify(JSON.parse(require("fs").readFileSync(0, "utf8"))[process.argv[1]]))' "$1"; }
command -v gh > /dev/null || { echo "protect-branch: the GitHub CLI gh is required" >&2; exit 2; }
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

part repository | gh api --method PATCH "repos/$repo" --input - > /dev/null
echo "== $repo: merge commits only, head branches deleted after the merge"
if out=$(part security | gh api --method PATCH "repos/$repo" --input - 2>&1 > /dev/null); then
  echo "== $repo: secret scanning and push protection on"
else
  printf '== %s: secret scanning and push protection not set; a private repository may need GitHub Advanced Security:\n%s\n' "$repo" "$out" >&2
fi
id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id" | head -n 1)
if [ -n "$id" ] && [ -z "$base" ]; then
  contexts=$(gh api "repos/$repo/rulesets/$id" --jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context') || {
    echo "protect-branch: cannot read the ruleset \"$name\" (id $id) of $repo; it is left unchanged" >&2
    exit 1
  }
  if printf '%s\n' "$contexts" | grep -qx base; then
    if [ -f .github/workflows/fail-without-change.yml ]; then
      base=1
      echo "== the ruleset \"$name\" requires \`base\`: kept (run with --require-base to say so)"
    else
      echo "== the ruleset \"$name\" requires \`base\`, which no workflow of this project reports: dropped" >&2
    fi
  fi
fi
if [ -n "$id" ]; then
  part ruleset | gh api --method PUT "repos/$repo/rulesets/$id" --input - > /dev/null
  echo "== updated the ruleset \"$name\" of $repo"
else
  part ruleset | gh api --method POST "repos/$repo/rulesets" --input - > /dev/null
  echo "== created the ruleset \"$name\" of $repo"
fi
