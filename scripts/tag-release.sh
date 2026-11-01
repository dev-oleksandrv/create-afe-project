#!/usr/bin/env bash
# Tags the version main is at once the Version PR is merged and no changesets are pending, then
# starts the release workflow on the tag (docs/maintaining.md, section 5). The version workflow
# runs it after changesets/action. A tag pushed with GITHUB_TOKEN starts no workflow, so the
# release is started with workflow_dispatch, the one event that token may trigger.
set -euo pipefail
cd "$(dirname "$0")/.."

# Read main itself: while changesets are pending, the action leaves the Version PR branch checked out.
git fetch --quiet origin main
ref=origin/main

# A changeset is pending when @changesets/parse, the parser changesets/action uses, finds a
# release in it. An empty one (`npx changeset --empty`) releases nothing, and the action opens no
# Version PR for it, so it must not block the tag. Files are skipped as @changesets/read skips
# them; a file that does not parse fails the script instead of being guessed.
pending=$(node -e '
const { execFileSync } = require("node:child_process");
const m = require("@changesets/parse");
const parse = m.default ?? m;
const ref = process.argv[1];
const git = (...args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 1 << 26 });
let n = 0;
for (const f of git("ls-tree", "-z", "--name-only", ref, ".changeset/").split("\0").filter(Boolean)) {
  const name = f.slice(f.lastIndexOf("/") + 1);
  if (!name.endsWith(".md") || name.startsWith(".") || /^(readme|agents|claude|gemini)\.md$/i.test(name)) continue;
  if (parse(git("show", `${ref}:${f}`)).releases.length > 0) n += 1;
}
console.log(n);
' "$ref")
if [ "$pending" != 0 ]; then
  echo "$pending changeset(s) pending: nothing to tag."
  exit 0
fi

version=$(git show "$ref:package.json" | node -p 'JSON.parse(require("fs").readFileSync(0, "utf8")).version')
tag="v$version"
if git ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null 2>&1; then
  echo "$tag already exists."
  exit 0
fi

git tag "$tag" "$ref"
git push origin "$tag"
gh workflow run release.yml --ref "$tag"
echo "Tagged $tag and started the release."
