# Merge readiness and path classes on variant A. Needs $a from 10-variant-a.sh and expect_fail,
# expect_pass, record from 30-negative.sh; defines body and writes $work/r-none.md for later files.
echo "== merge readiness on variant A"
# body <file> <acceptance item> [<extra sections>]: a description in the four sections of the
# create-pr skill; the change under test is the working tree of variant A against main.
body() {
  printf '## Summary\n\n- x\n\n## Acceptance and test plan\n\n%s\n\n## Checks\n\n- x\n\n## Open questions\n\nNone\n\n%s' "$2" "${3:-}" > "$1"
}
body "$work/r-ok.md" '- REQ-001: `scripts/check.sh` (`variant A`); failed on the base, passes now'
body "$work/r-none.md" '- None: documentation only'
body "$work/r-missing-test.md" '- REQ-001: `tests/missing_test.sh`; passes now'
body "$work/r-no-file.md" '- REQ-001: covered by the existing tests'
body "$work/r-gate.md" '- None: x' $'## Gate files\n\n- `scripts/checks.d/20-x.sh`: a new project check\n'
for s in "Summary" "Acceptance and test plan" "Checks" "Open questions"; do
  awk -v h="## $s" '$0 == h {skip = 1; next} /^## / {skip = 0} !skip' "$work/r-none.md" > "$work/r-no-$(printf '%s' "$s" | tr ' ' '-').md"
done
ready() { scripts/check-decisions.sh --ready --base main --pr-body "$1"; }
gatefile() { mkdir -p scripts/checks.d && printf '#!/bin/sh\n' > scripts/checks.d/20-x.sh; }
classes() { scripts/check-decisions.sh --classes --base main; }
export -f ready gatefile classes
export work
expect_pass "description with the four sections and acceptance evidence" bash -c 'ready "$work/r-ok.md"'
expect_pass "Acceptance None with a reason" bash -c 'ready "$work/r-none.md"'
for s in "Summary" "Acceptance and test plan" "Checks" "Open questions"; do
  (cd "$a" && ready "$work/r-no-$(printf '%s' "$s" | tr ' ' '-').md" > "$work/r-sec.log" 2>&1); [ $? -eq 1 ] &&
    grep -qxF "FAIL: pull request description: no '## $s' section" "$work/r-sec.log" ||
    { cat "$work/r-sec.log"; fail "readiness: a description without '## $s' passes, or the failure does not name it"; }
done
expect_fail "Acceptance names a test file that does not exist" bash -c 'ready "$work/r-missing-test.md"'
expect_fail "Acceptance item without a test file" bash -c 'ready "$work/r-no-file.md"'
expect_pass "labels, owner markers, and Metrics are no longer read" bash -c 'mkdir -p docs/plans && printf "A statement. Decided by the owner, 2026-10-30.\n" > docs/plans/x.md &&
  { cat "$work/r-none.md"; printf "\n## Assumptions and open questions\n\n- an item without a label\n"; } > "$work/r-old.md" && ready "$work/r-old.md"'
expect_pass "a root-level test file in Acceptance, a version that is no path" bash -c 'echo x > calc_test.go && sed "s#^- None: documentation only#- REQ-001: \`calc_test.go\` for \`v1.2.0\`; failed on the base#" "$work/r-none.md" > "$work/r-root.md" && ready "$work/r-root.md"'
expect_pass "a change at the limit, or in generated files, does not warn" bash -c 'seq 1 400 > big.txt && seq 1 500 >> docs/decisions/README.md && ! ready "$work/r-none.md" | grep -q WARNING'
expect_pass "the project takes a template deny entry out" bash -c 'printf "{\"remove\":{\"permissions\":{\"deny\":[\"Read(**/.env.*)\"]}}}\n" > .claude/settings.project.json && scripts/gen-settings.sh &&
  "$work/sj" "!s.permissions.deny.includes(\"Read(**/.env.*)\") && s.permissions.deny.includes(\"Read(**/.env)\") && !(\"remove\" in s)"'
expect_pass "a large change warns and still passes" bash -c 'seq 1 500 > big.txt && out=$(ready "$work/r-none.md") && printf "%s\n" "$out" | grep -q "WARNING: the change has 500 changed lines, more than DIFF_WARN_LINES (400)"'
expect_pass "a public contract is class high" bash -c 'mkdir -p contracts && echo x > contracts/api.yaml && classes | grep -qx "high	contracts/api.yaml"'
expect_pass "env.sh: an unset command is SKIP, a set one runs with its exit code" bash -c 'out=$(scripts/env.sh setup) && [ "$out" = "SKIP: SETUP is not set in .claude/harness.conf" ] &&
  scripts/env.sh fast > /dev/null && sed -i.bak "s/^E2E=.*/E2E=exit 3/" .claude/harness.conf && rm .claude/harness.conf.bak; scripts/env.sh e2e > /dev/null; [ $? -eq 3 ] && { scripts/env.sh nope 2> /dev/null; [ $? -eq 2 ]; }'
expect_pass "settings deny reading secrets" bash -c 'for r in "Read(**/.env)" "Read(**/.env.*)" "Read(**/*.pem)" "Read(**/*.key)"; do "$work/sj" "s.permissions.deny.includes(process.argv[1])" "$r" || exit 1; done'
expect_fail "a touched gate file not listed" bash -c 'gatefile && ready "$work/r-none.md"'
expect_pass "a touched gate file listed under Gate files" bash -c 'gatefile && ready "$work/r-gate.md"'
expect_pass "the gate paths of the template's path classes are class gate" bash -c '. scripts/lib/classes.sh &&
  for f in .github/workflows/ci.yml scripts/checks.d/20-x.sh .claude/hooks/project/stop/10-x.sh .claude/harness.conf \
    .claude/settings.project.json .claude/path-classes; do [ "$(class_of "$f")" = gate ] || { echo "not gate: $f"; exit 1; }; done'
expect_pass "no ecosystem block: manifests and tool configuration are normal until the project adds them" bash -c '. scripts/lib/classes.sh &&
  for f in package.json pyproject.toml go.mod Cargo.toml Makefile .pre-commit-config.yaml src/main.go; do
    [ "$(class_of "$f")" = normal ] || { echo "not normal: $f"; exit 1; }; done'
expect_pass "the high paths are class high, in any directory" bash -c '. scripts/lib/classes.sh &&
  for f in src/auth/login.py api/security/x.go secrets/k.txt db/migrations/1.sql billing/x.ts svc/payments/y.rb contracts/api.yaml; do
    [ "$(class_of "$f")" = high ] || { echo "not high: $f"; exit 1; }; done'
expect_pass "Markdown and generated files are low by the built-in rule; nothing else is" bash -c '. scripts/lib/classes.sh &&
  for f in AGENTS.md docs/x.md docs/decisions/0001-x.md .template/owned.sha256 .afe-answers.json .claude/settings.json; do
    [ "$(class_of "$f")" = low ] || { echo "not low: $f"; exit 1; }; done &&
  for f in .mcp.json .template/owned.txt scripts/check.sh .claude/settings.template.json; do [ "$(class_of "$f")" = normal ] || { echo "not normal: $f"; exit 1; }; done'
expect_pass "an approval or low line of an older project file is ignored" bash -c 'printf "approval src/*\nlow scripts/*\napproval .mcp.json\nnormal docs/*\nhigh docs/security/*\n" >> .claude/path-classes &&
  . scripts/lib/classes.sh && [ "$(class_of src/app.py)" = normal ] && [ "$(class_of scripts/x.sh)" = normal ] && [ "$(class_of .mcp.json)" = normal ] &&
  [ "$(class_of docs/x.md)" = low ] && [ "$(class_of docs/security/x.md)" = high ] && mkdir -p src && echo x > src/app.py && out=$(classes) &&
  printf "%s\n" "$out" | grep -qx "normal	src/app.py" && ! printf "%s\n" "$out" | grep -q "^approval"'
expect_pass "classes of the changed paths, review two for a high path" bash -c 'gatefile && mkdir -p docs/plans src/auth && echo x > docs/plans/x.md && echo x >> AGENTS.md &&
  echo x > src/app.py && echo x > src/auth/login.py && echo "{}" > .mcp.json && record 0001 accepted &&
  out=$(classes) && for l in "gate	scripts/checks.d/20-x.sh" "low	docs/plans/x.md" "low	AGENTS.md" "normal	src/app.py" \
    "high	src/auth/login.py" "normal	.mcp.json" "low	docs/decisions/0001-test.md" "review	two"; do
    printf "%s\n" "$out" | grep -qx "$l" || { echo "missing: $l"; printf "%s\n" "$out"; exit 1; }; done &&
  [ "$(printf "%s\n" "$out" | tail -n 1)" = "review	two" ]'
expect_pass "review: none for documents only" bash -c 'mkdir -p docs/plans && echo x > docs/plans/x.md && classes | grep -qx "review	none"'
expect_pass "review: one for code" bash -c 'mkdir -p src && echo x > src/app.py && classes | grep -qx "review	one"'
expect_pass "review: none for a template update" bash -c 'echo x >> docs/decisions/adr-template.md && echo x >> scripts/check.sh && echo " " >> .afe-answers.json && echo x >> .claude/harness.conf && classes | grep -qx "review	none"'
expect_pass "review: one for template-owned edits without an update" bash -c 'echo x >> docs/decisions/adr-template.md && echo x >> scripts/check.sh && classes | grep -qx "review	one"'
