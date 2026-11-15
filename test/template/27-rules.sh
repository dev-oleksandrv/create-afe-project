# The working rules of AGENTS.md and the testing rules: a document is updated when the change
# makes it false; test-first and an independent author of acceptance tests apply to class high,
# the regression test first to every defect; a test passes on the base only as a named invariant
# or characterization test; the Gate files list is information, not a control; and the pointer
# to .claude/rules/ works for any agent. Needs $a from 10-variant-a.sh.
echo "== rules: documents, test-first by class, evidence on the base, Gate files, rule pointers"
# Each document is joined into one line, so that a statement wrapped across lines is found too.
joined() { tr '\n' ' ' < "$1" | tr -s ' '; }
agents=$(joined "$a/AGENTS.md")
for s in 'Change a document only when a check fails on it, when the change makes a statement in it false, or when the change needs an ADR' \
  'Do not create placeholder documents.' \
  'A test of new behaviour or of a fix fails without the change for the intended reason; a test that passes on the base is named as an invariant or characterization test.' \
  'Read `.claude/rules/testing.md` before changing a test and `.claude/rules/docs.md` before changing a document'; do
  printf '%s' "$agents" | grep -qF -- "$s" || fail "AGENTS.md lacks '$s'"
done
! printf '%s' "$agents" | grep -q -F -e 'A new or changed test fails without the change.' -e '`.claude/rules/` loads the rules' ||
  fail "AGENTS.md keeps the universal fail-on-base rule or the pointer that holds for Claude Code only"
testing=$(joined "$a/.claude/rules/testing.md")
for s in 'For a change that touches a path of class high (`.claude/path-classes`), tests come first' \
  'written or reviewed by someone other than the author of the implementation' 'Elsewhere, tests are written with the change.' \
  'A defect is fixed only after a regression test that reproduces it fails, whatever the class.' \
  'fails on the base for the intended reason and passes with the change, and the pull request says how that was seen' \
  'or a characterization test written before a refactoring, may pass on the base; the pull request names it as such' \
  'That list is information for the owner, not a control'; do
  printf '%s' "$testing" | grep -qF -- "$s" || fail "testing.md lacks '$s'"
done
! printf '%s' "$testing" | grep -q -F -e 'the owner reviews it after the merge' -e 'Each new or changed test fails on the base' \
  -e 'A test that passes before the implementation exists tests nothing' ||
  fail "testing.md keeps the claimed review after the merge or the universal fail-on-base rule"
