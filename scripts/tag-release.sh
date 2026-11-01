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

# A changeset is pending when its front matter names a package. An empty one (`npx changeset
# --empty`) releases nothing, and changesets/action opens no Version PR for it, so it must not
# block the tag.
pending=0
while IFS= read -r f; do
  case "$f" in *.md) ;; *) continue ;; esac
  [ "${f##*/}" = README.md ] && continue
  git show "$ref:$f" | awk 'NR == 1 && /^---/ {fm = 1; next} fm && /^---/ {exit} fm && NF {n++} END {exit n ? 0 : 1}' &&
    pending=$((pending + 1))
done < <(git ls-tree --name-only "$ref" .changeset/)
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
