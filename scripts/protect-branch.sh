#!/usr/bin/env bash
# Protects the default branch on GitHub and applies the repository settings that AGENTS.md
# assumes, with the GitHub CLI. A repository admin runs it once after the first push, and again
# after a template update that changes the required checks; a change of repository settings is
# an owner action, so an agent runs it only on the owner's explicit instruction. In this order:
# 1. Merge commits only, and "Automatically delete head branches".
# 2. Secret scanning with push protection; a refusal by the plan (a private repository may need
#    GitHub Advanced Security) is reported and the script goes on.
# 3. The repository ruleset "protect default branch": a pull request merged with a merge commit,
#    no deletion or force push, and the check `check`. Without rulesets on the plan, the script
#    says so and ends without error.
#
# Usage: scripts/protect-branch.sh [--dry-run] [--repo owner/name]
#   --dry-run  print the settings and the ruleset as one JSON object and change nothing
#   --repo     the repository; default: the one of the current directory
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
plan() { node -e '
  const [name] = process.argv.slice(1);
  const checks = [{ context: "check" }];
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
  }, null, 2));' "$name"; }

if [ -n "$dry" ]; then
  plan
  exit 0
fi
part() { plan | node -e 'console.log(JSON.stringify(JSON.parse(require("fs").readFileSync(0, "utf8"))[process.argv[1]]))' "$1"; }
command -v gh > /dev/null || { echo "protect-branch: the GitHub CLI gh is required" >&2; exit 2; }
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# On an HTTP error, gh api prints the response body on stdout, "gh: <message> (HTTP <status>)" on
# stderr, and exits with 1; status prints that status, or nothing when no response came.
status() { printf '%s\n' "$1" | sed -n 's/.*(HTTP \([0-9][0-9]*\))$/\1/p' | tail -n 1; }

err=$(mktemp) secret=
# On every exit, a secret scanning that failed for a reason other than the plan is named again in
# the last line.
trap 'rm -f "$err"; [ -z "$secret" ] || echo "protect-branch: secret scanning and push protection are not enabled on $repo; see the error above" >&2' EXIT

part repository | gh api --method PATCH "repos/$repo" --input - > /dev/null
echo "== $repo: merge commits only, head branches deleted after the merge"
# A refusal by the plan (HTTP 403 or 422 that names Advanced Security, an upgrade, a purchase, or
# the feature as not available) goes on; any other error goes on to the ruleset too, and the run
# fails at the end.
if out=$(part security | gh api --method PATCH "repos/$repo" --input - 2>&1); then
  echo "== $repo: secret scanning and push protection on"
else
  case "$(status "$out")" in
    403|422) printf '%s\n' "$out" | grep -qiE 'advanced security|not available|purchase|upgrade' && refused=1 || refused= ;;
    *) refused= ;;
  esac
  if [ -n "$refused" ]; then
    printf '== %s: secret scanning and push protection not set; a private repository may need GitHub Advanced Security:\n%s\n' "$repo" "$out" >&2
  else
    secret=1
    printf 'protect-branch: cannot enable secret scanning on %s; the ruleset is applied all the same:\n%s\n' "$repo" "$out" >&2
  fi
fi
# All pages, and only the repository's own rulesets, not those inherited from an organisation.
# With --paginate, gh applies --jq to each page and prints the results one after the other.
if ! ids=$(gh api --paginate "repos/$repo/rulesets?includes_parents=false" --jq ".[] | select(.name == \"$name\") | .id" 2> "$err"); then
  out=$(cat "$err")
  case "$(status "$out")" in
    403|404)
      printf '== %s: rulesets are not available for this repository on its plan; the settings above are applied, and the rule on the default branch rests on the owner and review:\n%s\n' "$repo" "$out" >&2
      [ -z "$secret" ] || exit 1
      exit 0 ;;
  esac
  printf 'protect-branch: cannot list the rulesets of %s:\n%s\n' "$repo" "$out" >&2
  exit 1
fi
id=$(printf '%s\n' "$ids" | head -n 1)
if [ -n "$id" ]; then
  part ruleset | gh api --method PUT "repos/$repo/rulesets/$id" --input - > /dev/null
  echo "== updated the ruleset \"$name\" of $repo"
else
  part ruleset | gh api --method POST "repos/$repo/rulesets" --input - > /dev/null
  echo "== created the ruleset \"$name\" of $repo"
fi
[ -z "$secret" ] || exit 1
