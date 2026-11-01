#!/usr/bin/env bash
# Tests of scripts/tag-release.sh (docs/maintaining.md, sections 3 and 5): in a scratch repository
# with a local origin and a stand-in for gh, it tags main only when no changeset with a release is
# pending; an empty changeset (`npx changeset --empty`) releases nothing and blocks nothing.
set -uo pipefail
cd "$(dirname "$0")/../.."
root=$PWD
[ -d node_modules ] || npm ci --silent > /dev/null 2>&1 || { echo "FAIL: npm ci fails"; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
echo "== release tagging"

mkdir -p "$work/bin" && printf '#!/usr/bin/env bash\necho "gh $*" >> "%s/gh.log"\n' "$work" > "$work/bin/gh" && chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# scenario <name> <changeset content or "none">: a repository at version 1.2.3 whose main holds
# .changeset/README.md and, unless "none", .changeset/x.md with that content; prints the output.
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
  rm -f "$work/gh.log"
  (cd "$d/repo" && scripts/tag-release.sh 2>&1)
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
! tagged leading || fail "a release changeset after a blank line is not pending ($out)"
out=$(scenario comment $'---\n# a note\n---\n')
tagged comment || fail "a changeset with only a comment blocks the tag ($out)"
out=$(scenario crlf $'---\r\n"create-afe-project": minor\r\n---\r\n\r\nA change.\r\n')
! tagged crlf || fail "a release changeset with CRLF line endings is not pending ($out)"
out=$(scenario broken $'---\n"create-afe-project": [\n---\n')
! tagged broken || fail "a changeset that does not parse lets the tag through ($out)"

if [ "$failures" -gt 0 ]; then
  echo "== release tests failed: $failures"
  exit 1
fi
echo "== release tests passed"
