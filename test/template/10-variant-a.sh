# Variant A: renders the GitHub-hosted default project into $a, which later files reuse, and runs
# its checks. Needs lib.sh only.
echo "== variant A: GitHub-hosted runner, the default modules (code-review off, acceptance check on)"
a="$work/a"
render "$a" || fail "variant A does not render"
(cd "$a" && scripts/check.sh > "$work/a.log" 2>&1) || { cat "$work/a.log"; fail "variant A: scripts/check.sh fails"; }
# The default project has check.yml, the single CI path through scripts/check.sh, and none of the
# removed docs-review and dual-review modules.
[ -f "$a/.github/workflows/check.yml" ] && [ ! -e "$a/.github/workflows/docs.yml" ] ||
  fail "variant A: .github/workflows/check.yml is missing, or docs.yml still exists"
grep -q '^name: check$' "$a/.github/workflows/check.yml" && grep -q '^  check:$' "$a/.github/workflows/check.yml" &&
  grep -q 'run: scripts/env.sh setup$' "$a/.github/workflows/check.yml" &&
  grep -q 'run: scripts/check.sh --verbose$' "$a/.github/workflows/check.yml" &&
  grep -q 'fetch-depth: 0' "$a/.github/workflows/check.yml" && ! grep -q markdownlint "$a/.github/workflows/check.yml" ||
  fail "variant A: check.yml does not run scripts/env.sh setup and scripts/check.sh --verbose in its job check"
grep -q 'ubuntu-latest' "$a/.github/workflows/check.yml" || fail "variant A: check.yml lacks the GitHub-hosted default"
find "$a" -path "$a/.git" -prune -o \( -name '*docs-review*' -o -name '*dual-review*' \) -print > "$work/a-find.log"
[ ! -s "$work/a-find.log" ] || { cat "$work/a-find.log"; fail "variant A: docs-review or dual-review files exist"; }
! grep -r -n 'docs-review\|dual-review' "$a/AGENTS.md" "$a/README.md" "$a/docs" "$a/.claude/skills" "$a/.github" "$a/.template/owned.txt" > "$work/a-grep.log" ||
  { cat "$work/a-grep.log"; fail "variant A: a document, skill, or workflow names the removed docs-review or dual-review module"; }
grep -q 'GITLEAKS_VERSION: [0-9]' "$a/.github/workflows/secret-scan.yml" && grep -q 'runs-on: ${{ fromJSON(vars.CI_RUNS_ON' "$a/.github/workflows/secret-scan.yml" ||
  fail "variant A: the secret-scan workflow is missing or not rendered"
[ ! -e "$a/.github/workflows/code-review.yml" ] && [ ! -e "$a/.claude/skills/review-code" ] ||
  fail "variant A: code-review files exist although the module is off by default"
[ -x "$a/scripts/check-acceptance.sh" ] && grep -qx 'scripts/check-acceptance.sh' "$a/.template/owned.txt" ||
  fail "variant A: the acceptance check is missing although it is on by default"
grep -q '"code_review": false' "$a/.afe-answers.json" && grep -q '"acceptance_check": true' "$a/.afe-answers.json" &&
  ! grep -q 'docs_review\|dual_review' "$a/.afe-answers.json" || { cat "$a/.afe-answers.json"; fail "variant A: the answers file does not record the 3.0.0 defaults"; }
# Each document is joined into one line, so that a statement wrapped across lines is caught too.
: > "$work/a-grep.log"
for f in "$a/AGENTS.md" "$a/README.md" $(find "$a/docs" "$a/.claude" -name '*.md'); do
  tr '\n' ' ' < "$f" | grep -q -i -E 'never (chang|alter|touch|modif|replac)[a-z]* [^.]*seeded' && echo "$f" >> "$work/a-grep.log"
done
[ ! -s "$work/a-grep.log" ] &&
  grep -qF 'runs the migrations the changelog names, the only way it changes an existing seeded file' "$a/.claude/skills/update-template/SKILL.md" ||
  { cat "$work/a-grep.log"; fail "variant A: a rule document says an update never changes a seeded file, without the migration exception"; }
