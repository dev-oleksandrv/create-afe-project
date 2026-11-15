#!/usr/bin/env bash
# Tests of scripts/tag-release.sh (docs/maintaining.md, sections 3 and 5): in a scratch repository
# with a local origin and a stand-in for gh, it tags main only when no changeset with a release is
# pending; an empty changeset (`npx changeset --empty`) releases nothing and blocks nothing; and
# for a tag that exists it starts the release again only when no run of it is in progress or
# succeeded.
set -uo pipefail
cd "$(dirname "$0")/../.."
root=$PWD
[ -d node_modules ] || npm ci --silent > /dev/null 2>&1 || { echo "FAIL: npm ci fails"; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
echo "== release tagging"

# The stand-in logs its arguments and answers `gh run list` with the content of $work/gh-runs, the
# last release run of the tag as `<status> <conclusion>` (empty: no run).
mkdir -p "$work/bin" && printf '#!/usr/bin/env bash\necho "gh $*" >> "%s/gh.log"\n[ "$1 $2" != "run list" ] || cat "%s/gh-runs" 2> /dev/null\n' "$work" "$work" > "$work/bin/gh" && chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# scenario <name> <changeset content or "none"> [tagged]: a repository at version 1.2.3 whose main
# holds .changeset/README.md and, unless "none", .changeset/x.md with that content, and with
# "tagged" the tag v1.2.3 on its origin already; prints the output.
scenario() {
  local d="$work/$1"
  git init -q --bare "$d/origin.git" && git init -q -b main "$d/repo"
  mkdir -p "$d/repo/scripts" "$d/repo/.changeset"
  cp "$root/scripts/tag-release.sh" "$d/repo/scripts/"
  ln -s "$root/node_modules" "$d/repo/node_modules"
  printf '{"version": "1.2.3"}\n' > "$d/repo/package.json"
  printf '# Changesets\n' > "$d/repo/.changeset/README.md"
  printf 'node_modules\n' > "$d/repo/.gitignore"
  [ "$2" = none ] || printf '%s' "$2" > "$d/repo/.changeset/x.md"
  git -C "$d/repo" add -A && git -C "$d/repo" commit -q -m init
  git -C "$d/repo" remote add origin "$d/origin.git" && git -C "$d/repo" push -q origin main
  [ "${3:-}" != tagged ] || { git -C "$d/repo" tag v1.2.3 && git -C "$d/repo" push -q origin v1.2.3 && git -C "$d/repo" tag -d v1.2.3 > /dev/null; }
  rm -f "$work/gh.log"
  (cd "$d/repo" && scripts/tag-release.sh 2>&1)
  echo "exit=$?"
}
tagged() { git -C "$work/$1/origin.git" rev-parse -q --verify refs/tags/v1.2.3 > /dev/null; }

out=$(scenario none none)
tagged none && grep -q 'gh workflow run release.yml --ref v1.2.3' "$work/gh.log" ||
  fail "no changeset: main is not tagged and released ($out)"

out=$(scenario empty $'---\n---\n')
tagged empty && grep -q 'gh workflow run release.yml --ref v1.2.3' "$work/gh.log" ||
  fail "an empty changeset blocks the tag ($out)"

out=$(scenario pending $'---\n"create-afe-project": minor\n---\n\nA change.\n')
! tagged pending && [ ! -e "$work/gh.log" ] && printf '%s' "$out" | grep -q '1 changeset(s) pending' ||
  fail "a pending changeset with a release does not stop the tag ($out)"

# Forms where a line-based reading and @changesets/parse disagree: leading blank line, comment-only
# front matter, CRLF line endings.
out=$(scenario leading $'\n---\n"create-afe-project": minor\n---\n\nA change.\n')
! tagged leading && printf '%s' "$out" | grep -q '1 changeset(s) pending' && printf '%s' "$out" | grep -q 'exit=0$' ||
  fail "a release changeset after a blank line is not pending ($out)"
out=$(scenario comment $'---\n# a note\n---\n')
tagged comment || fail "a changeset with only a comment blocks the tag ($out)"
out=$(scenario crlf $'---\r\n"create-afe-project": minor\r\n---\r\n\r\nA change.\r\n')
! tagged crlf && printf '%s' "$out" | grep -q '1 changeset(s) pending' && printf '%s' "$out" | grep -q 'exit=0$' ||
  fail "a release changeset with CRLF line endings is not pending ($out)"
out=$(scenario broken $'---\n"create-afe-project": [\n---\n')
! tagged broken && printf '%s' "$out" | grep -q 'could not parse changeset' && ! printf '%s' "$out" | grep -q 'exit=0$' ||
  fail "a changeset that does not parse does not fail the script with the parse error ($out)"

# A tag that exists: the release starts again when no run of it exists or the last one failed,
# and not while one is in progress or after one succeeded.
for runs in '' 'completed failure' 'completed cancelled'; do
  printf '%s' "$runs" > "$work/gh-runs"
  out=$(scenario "again-${runs// /-}" none tagged)
  grep -q 'gh run list --workflow release.yml --branch v1.2.3' "$work/gh.log" 2> /dev/null &&
    grep -q 'gh workflow run release.yml --ref v1.2.3' "$work/gh.log" 2> /dev/null && printf '%s' "$out" | grep -q 'started its release again' ||
    fail "an existing tag whose last release run is '${runs:-none}' does not start the release ($out)"
done
for runs in 'in_progress ' 'queued ' 'completed success'; do
  printf '%s' "$runs" > "$work/gh-runs"
  out=$(scenario "done-${runs// /-}" none tagged)
  grep -q 'gh run list --workflow release.yml --branch v1.2.3' "$work/gh.log" 2> /dev/null &&
    ! grep -q 'gh workflow run' "$work/gh.log" && printf '%s' "$out" | grep -q 'exit=0$' ||
    fail "an existing tag whose last release run is '$runs' starts the release again ($out)"
done
rm -f "$work/gh-runs"

# The release workflow publishes only after the full check of the tagged commit and an install of
# the packed package that prints the tag's version.
awk '/scripts\/check\.sh --verbose/ {c = NR} /npm install .*\.tgz/ {i = NR} /create-afe-project --version/ {v = NR}
     /npm publish/ {p = NR} END {exit !(c && i && v && p && c < p && i < p && v < p)}' .github/workflows/release.yml ||
  fail "release.yml publishes without the full check or the install of the packed package"

if [ "$failures" -gt 0 ]; then
  echo "== release tests failed: $failures"
  exit 1
fi
echo "== release tests passed"
