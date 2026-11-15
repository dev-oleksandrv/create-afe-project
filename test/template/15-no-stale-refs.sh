# The rules and documents: no generated file names a removed file or vocabulary, AGENTS.md is
# within its line budget, and the scoped rules exist with their paths front matter. Needs $a from
# 10-variant-a.sh and $b from 13-variant-b.sh; defines no_stale_refs, which 81-smoke-modules.sh
# runs on $c and $d.
echo "== rules and documents: no stale references, AGENTS.md budget, scoped rules"

# no_stale_refs <dir> <label>: no file of the generated project, Git metadata aside, names a
# file, a document, or the vocabulary that 3.0.0 or 5.0.0 removed.
no_stale_refs() {
  ! grep -r -n -F --exclude-dir=.git -e 'documentation-rules.md' -e 'contributing.md' -e 'testing-rules.md' \
    -e 'docs/README.md' -e 'Decided by the owner' -e 'Metrics' -e 'Santa' -e 'verified-against' -e 'review-by' \
    -e 'protect hook' -e 'class approval' \
    -e 'create-pr' -e 'skills/review/' -e 'rubric' -e 'check-decisions' -e 'gen-decisions-index' -e 'path-classes' \
    -e 'stop-dispatch' -e 'Stop dispatcher' -e 'stamp' -e '--if-changed' -e 'Gate files' -e 'class gate' -e 'class high' \
    -e 'readiness' -e 'check-acceptance' -e 'fail-without-change' -e 'ID_PATTERN' -e 'RALPH' -e 'REVIEW_MAX_ROUNDS' \
    -e 'Acceptance and test plan' "$1" > "$work/$2-stale.log" ||
    { cat "$work/$2-stale.log"; fail "variant $2: a generated file names a removed file or vocabulary"; }
}
no_stale_refs "$a" A
no_stale_refs "$b" B

for v in a b; do
  d="$work/$v"
  for f in .claude/rules/testing.md .claude/rules/docs.md; do
    [ -f "$d/$f" ] && grep -qxF "$f" "$d/.template/owned.txt" || fail "variant $v: $f is missing or not template-owned"
  done
  # AGENTS.md: the template part at most 70 lines, the project block at most 20 and first, the
  # sections in their order, and a place for how to run the product.
  block=$(awk '$0=="<!-- project:start -->" {f=1; next} $0=="<!-- project:end -->" {f=0} f' "$d/AGENTS.md" | wc -l | tr -d ' ')
  total=$(wc -l < "$d/AGENTS.md" | tr -d ' ')
  [ $((total - block)) -le 70 ] && [ "$block" -le 20 ] ||
    fail "variant $v: AGENTS.md has $((total - block)) template lines and $block block lines; at most 70 and 20"
  got=$(grep '^## ' "$d/AGENTS.md" | tr '\n' '|')
  [ "$got" = '## Commands|## Limits|## Tests and documents|' ] || fail "variant $v: AGENTS.md sections are '$got'"
  [ "$(grep -n -x -F '<!-- project:end -->' "$d/AGENTS.md" | cut -d: -f1)" -lt "$(grep -n -x '## Commands' "$d/AGENTS.md" | cut -d: -f1)" ] ||
    fail "variant $v: the project block of AGENTS.md does not come first"
  awk '$0=="<!-- project:start -->" {f=1; next} $0=="<!-- project:end -->" {f=0} f' "$d/AGENTS.md" | grep -q '^Run and see: ' ||
    fail "variant $v: the project block of AGENTS.md has no place for how to run the product"
  [ "$(wc -w < "$d/AGENTS.md" | tr -d ' ')" -le 400 ] || fail "variant $v: AGENTS.md has more than 400 words"
  # The link and code-path check passes on the generated documents.
  (cd "$d" && node scripts/check-links.mjs > "$work/$v-links.log" 2>&1) ||
    { cat "$work/$v-links.log"; fail "variant $v: the link and code-path check fails on the generated documents"; }
done

# The scoped rules: front matter that holds only paths, as a YAML list, no @import, and short.
# front <file>: the lines between the opening and the closing --- of the front matter.
front() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }
r="$a/.claude/rules"
[ "$(sed -n 1p "$r/testing.md")" = '---' ] && [ "$(front "$r/testing.md" | tr '\n' '|')" = 'paths:|  - "**/*.test.*"|  - "**/*.spec.*"|  - "**/*_test.*"|  - "**/test_*.py"|  - "**/test/**"|  - "**/tests/**"|  - "**/__tests__/**"|' ] ||
  fail "testing.md: the front matter is not exactly the paths list of the test files"
[ "$(sed -n 1p "$r/docs.md")" = '---' ] && [ "$(front "$r/docs.md" | tr '\n' '|')" = 'paths:|  - "docs/**"|  - "*.md"|' ] ||
  fail "docs.md: the front matter is not exactly the paths list docs/** and *.md"
[ "$(wc -l < "$r/docs.md" | tr -d ' ')" -le 40 ] && [ "$(wc -l < "$r/testing.md" | tr -d ' ')" -le 40 ] || fail "a scoped rule has more than 40 lines"
! grep -n -E '(^|[[:space:]])@[^[:space:]]' "$r/testing.md" "$r/docs.md" > "$work/rules-import.log" ||
  { cat "$work/rules-import.log"; fail "a scoped rule holds an @import, which loads at session start"; }
# A decision record has no status to move.
! grep -q -E '^(status|decision-makers):' "$a/docs/decisions/adr-template.md" || fail "adr-template.md still has a status or decision-makers field"
