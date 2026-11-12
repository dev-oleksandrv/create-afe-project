# The rules and documents of 3.0.0: no generated file names a removed document or vocabulary,
# AGENTS.md is within its line budget, the scoped rules exist with their paths front matter, and
# the code-path check passes on the generated documents. Needs $a from 10-variant-a.sh and $b
# from 13-variant-b.sh; defines no_stale_refs, which 81-smoke-python.sh runs on $c and $d.
echo "== rules and documents: no stale references, AGENTS.md budget, scoped rules"

# no_stale_refs <dir> <label>: no file of the generated project, Git metadata aside, names a
# deleted rule document, the documentation map, or the removed metadata, tables, and vocabulary.
no_stale_refs() {
  ! grep -r -n -F --exclude-dir=.git -e 'documentation-rules.md' -e 'contributing.md' -e 'testing-rules.md' \
    -e 'docs/README.md' -e 'Decided by the owner' -e 'Metrics' -e 'Santa' -e 'verified-against' -e 'review-by' \
    -e 'protect hook' -e 'class approval' "$1" > "$work/$2-stale.log" ||
    { cat "$work/$2-stale.log"; fail "variant $2: a generated file names a removed document or vocabulary"; }
}
no_stale_refs "$a" A
no_stale_refs "$b" B

for v in a b; do
  d="$work/$v"
  # The deleted documents are gone and no longer template-owned; the scoped rules are.
  for f in docs/documentation-rules.md docs/contributing.md docs/testing-rules.md docs/README.md; do
    [ ! -e "$d/$f" ] && ! grep -qxF "$f" "$d/.template/owned.txt" || fail "variant $v: $f still exists or is template-owned"
  done
  for f in .claude/rules/testing.md .claude/rules/docs.md; do
    [ -f "$d/$f" ] && grep -qxF "$f" "$d/.template/owned.txt" || fail "variant $v: $f is missing or not template-owned"
  done
  # AGENTS.md: the template part at most 70 lines, the project block at most 10, the sections in
  # their order, and no status vocabulary or precedence list.
  block=$(awk '$0=="<!-- project:start -->" {f=1; next} $0=="<!-- project:end -->" {f=0} f' "$d/AGENTS.md" | wc -l | tr -d ' ')
  total=$(wc -l < "$d/AGENTS.md" | tr -d ' ')
  [ $((total - block)) -le 70 ] && [ "$block" -le 10 ] ||
    fail "variant $v: AGENTS.md has $((total - block)) template lines and $block block lines; at most 70 and 10"
  got=$(grep '^## ' "$d/AGENTS.md" | tr '\n' '|')
  [ "$got" = '## Commands|## Working rules|## Done|## Documents|## Pull requests|## Pointers|' ] ||
    fail "variant $v: AGENTS.md sections are '$got'"
  [ "$(grep -n -x -F '<!-- project:end -->' "$d/AGENTS.md" | cut -d: -f1)" -lt "$(grep -n -x '## Commands' "$d/AGENTS.md" | cut -d: -f1)" ] ||
    fail "variant $v: the project block of AGENTS.md does not come first"
  ! grep -n -E 'implemented|accepted|proposed|precedence|\| --- \|' "$d/AGENTS.md" > "$work/$v-agents.log" ||
    { cat "$work/$v-agents.log"; fail "variant $v: AGENTS.md keeps the status vocabulary, the precedence list, or a table"; }
  # The code-path check passes on the generated documents.
  (cd "$d" && node scripts/check-links.mjs > "$work/$v-links.log" 2>&1) ||
    { cat "$work/$v-links.log"; fail "variant $v: the link and code-path check fails on the generated documents"; }
done

# The scoped rules: front matter that holds only paths, as a YAML list, and no @import.
# front <file>: the lines between the opening and the closing --- of the front matter.
front() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }
r="$a/.claude/rules"
[ "$(sed -n 1p "$r/testing.md")" = '---' ] && [ "$(front "$r/testing.md" | tr '\n' '|')" = 'paths:|  - "**/*.test.*"|  - "**/*.spec.*"|  - "**/*_test.*"|  - "**/test_*.py"|  - "**/test/**"|  - "**/tests/**"|  - "**/__tests__/**"|' ] ||
  fail "testing.md: the front matter is not exactly the paths list of the test files"
[ "$(sed -n 1p "$r/docs.md")" = '---' ] && [ "$(front "$r/docs.md" | tr '\n' '|')" = 'paths:|  - "docs/**"|  - "*.md"|' ] ||
  fail "docs.md: the front matter is not exactly the paths list docs/** and *.md"
[ "$(wc -l < "$r/docs.md" | tr -d ' ')" -le 40 ] || fail "docs.md has more than 40 lines"
! grep -n -E '(^|[[:space:]])@[^[:space:]]' "$r/testing.md" "$r/docs.md" > "$work/rules-import.log" ||
  { cat "$work/rules-import.log"; fail "a scoped rule holds an @import, which loads at session start"; }
# testing.md keeps the four sections of the testing rules, which the rubric's "section 4" names.
[ "$(grep '^## ' "$r/testing.md" | tr '\n' '|')" = '## 1. What a test is for|## 2. How a test proves behaviour|## 3. Tests and the change they cover|## 4. Gates|' ] ||
  fail "testing.md does not keep sections 1 to 4 of the testing rules"
for s in 'Threat model of development gates' 'which the readiness check enforces' 'A defect is fixed only after a regression test'; do
  grep -qF -- "$s" "$r/testing.md" || fail "testing.md lacks '$s'"
done
# docs.md states the ADR criterion, which adr-template.md repeats.
for s in 'costly to reverse and had a real alternative' 'never enter `docs/`' 'link to it, never copy it'; do
  grep -qF -- "$s" "$r/docs.md" || fail "docs.md lacks '$s'"
done
grep -qF 'is costly to reverse and had a real alternative' "$a/docs/decisions/adr-template.md" ||
  fail "adr-template.md does not state the ADR criterion"
