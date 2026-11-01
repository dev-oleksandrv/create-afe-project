#!/usr/bin/env bash
# Template tests (docs/maintaining.md, section 3): render the template in four projects and run the
# generated project's checks, prove that the checks catch violations, and confirm that this
# repository's own template-owned files match template/.
set -uo pipefail
cd "$(dirname "$0")/../.."
# The templates render with the CLI of this working tree (bin/create-afe-project.js); its
# dependencies come from npm ci when node_modules is missing.
root=$PWD
[ -d node_modules ] || npm ci --silent > /dev/null 2>&1 || { echo "FAIL: npm ci fails"; exit 1; }
cli() { node "$root/bin/create-afe-project.js" "$@"; }

work=$(mktemp -d)
export work
trap 'rm -rf "$work"' EXIT
failures=0
# sj <expression> [argument]: true when the JavaScript expression holds for s, the parsed
# .claude/settings.json of the current directory.
printf '%s\n' '#!/usr/bin/env node' 'const s = JSON.parse(require("fs").readFileSync(".claude/settings.json", "utf8"));' \
  'process.exit(new Function("s", "process", "return (" + process.argv[2] + ");")(s, { argv: process.argv.slice(2) }) ? 0 : 1);' > "$work/sj"
chmod +x "$work/sj"
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
gitc() { git -C "$1" -c user.name=test -c user.email=test@example.com "${@:2}"; }
# The CLI makes the initial commit of a new project with the identity of the environment.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

render() {
  local d="$1"; shift
  cli "$d" --defaults --quiet --data project_name=sample \
    --data 'project_description=A sample project.' --data github_repo=example/sample "$@" \
    > "$work/render.log" 2>&1 || { cat "$work/render.log"; return 1; }
  # The CLI commits the generated files as the only commit on main and leaves a clean tree.
  [ "$(git -C "$d" rev-parse --abbrev-ref HEAD)" = main ] && [ "$(git -C "$d" rev-list --count HEAD)" = 1 ] &&
    [ -z "$(git -C "$d" status --porcelain)" ] && grep -q 'committed on main' "$work/render.log" ||
    { git -C "$d" status --short | head; cat "$work/render.log"; fail "$d: the CLI does not make the initial commit on main"; return 1; }
}

echo "== variant A: GitHub-hosted runner, the default modules (docs-review and code-review on, dual review off)"
a="$work/a"
render "$a" || fail "variant A does not render"
(cd "$a" && scripts/check.sh > "$work/a.log" 2>&1) || { cat "$work/a.log"; fail "variant A: scripts/check.sh fails"; }
grep -q 'ubuntu-latest' "$a/.github/workflows/docs.yml" || fail "variant A: docs.yml lacks the GitHub-hosted default"
grep -q 'GITLEAKS_VERSION: [0-9]' "$a/.github/workflows/secret-scan.yml" && grep -q 'runs-on: ${{ fromJSON(vars.CI_RUNS_ON' "$a/.github/workflows/secret-scan.yml" ||
  fail "variant A: the secret-scan workflow is missing or not rendered"
[ -f "$a/.github/workflows/code-review.yml" ] && [ -f "$a/.claude/skills/review-code/SKILL.md" ] ||
  fail "variant A: code-review files are missing although the module is on"
[ ! -e "$a/.claude/skills/dual-review" ] || fail "variant A: dual-review files exist although the module is off"
! grep -r -n -i 'dual.review' "$a/AGENTS.md" "$a/docs" "$a/.claude/skills" > "$work/a-grep.log" || { cat "$work/a-grep.log"; fail "variant A: documents mention the dual review"; }

echo "== initial commit: --no-git, an empty clone, a forced non-empty directory"
ng="$work/ng"
cli "$ng" --defaults --quiet --no-git --data project_name=sample --data 'project_description=A sample project.' \
  --data github_repo=example/sample > "$work/ng.log" 2>&1 && [ ! -e "$ng/.git" ] && grep -q 'skipped with --no-git' "$work/ng.log" ||
  { cat "$work/ng.log"; fail "--no-git still initializes Git"; }
ec="$work/ec"
git init -q -b trunk "$ec" && cli "$ec" --defaults --quiet --data project_name=sample --data 'project_description=A sample project.' \
  --data github_repo=example/sample > "$work/ec.log" 2>&1 && [ "$(git -C "$ec" rev-parse --abbrev-ref HEAD)" = main ] &&
  [ -z "$(git -C "$ec" status --porcelain)" ] || { cat "$work/ec.log"; fail "an empty clone does not get the initial commit on main"; }
fd="$work/fd"
mkdir -p "$fd" && echo mine > "$fd/own.txt" && cli "$fd" --defaults --quiet --force --data project_name=sample \
  --data 'project_description=A sample project.' --data github_repo=example/sample > "$work/fd.log" 2>&1 && [ ! -e "$fd/.git" ] &&
  grep -q 'not made here: the directory was not empty' "$work/fd.log" || { cat "$work/fd.log"; fail "a forced non-empty directory is committed"; }

echo "== interactive create in a terminal exits after its outro"
# In a terminal the CLI shows a spinner; create logs more than one step, and a spinner started
# twice keeps a timer alive, so the process never exits. `script` provides the terminal.
if command -v script > /dev/null 2>&1; then
  it="$work/it"
  itcmd=(node "$root/bin/create-afe-project.js" "$it" --data project_name=sample --data 'project_description=A sample project.'
    --data github_repo=example/sample --data ci_runner=github-hosted --data docs_review=true --data code_review=true
    --data dual_review=false --data secret_scan=true --data acceptance_check=false --data fail_without_change=false)
  if script --version > /dev/null 2>&1; then
    script -qec "$(printf '%q ' "${itcmd[@]}")" /dev/null > "$work/it.log" 2>&1 < /dev/null &
  else
    script -q /dev/null "${itcmd[@]}" > "$work/it.log" 2>&1 < /dev/null &
  fi
  itpid=$!
  for _ in $(seq 1 240); do grep -q 'is ready' "$work/it.log" 2> /dev/null && break; kill -0 "$itpid" 2> /dev/null || break; sleep 0.25; done
  for _ in $(seq 1 20); do kill -0 "$itpid" 2> /dev/null || break; sleep 0.25; done
  if kill -0 "$itpid" 2> /dev/null; then
    pkill -f "create-afe-project.js $it " 2> /dev/null; kill "$itpid" 2> /dev/null
    fail "interactive create does not exit after its outro"
  else
    grep -q 'is ready' "$work/it.log" && [ -z "$(git -C "$it" status --porcelain 2> /dev/null)" ] &&
      [ "$(git -C "$it" rev-list --count HEAD 2> /dev/null)" = 1 ] || { tail -n 20 "$work/it.log"; fail "interactive create does not finish with the initial commit"; }
  fi
else
  echo "SKIP: script is not installed; the interactive create is not tested"
fi

echo "== variant B: self-hosted runner, docs-review and code-review off, dual review on"
b="$work/b"
render "$b" --data ci_runner=self-hosted --data docs_review=false --data code_review=false --data dual_review=true ||
  fail "variant B does not render"
(cd "$b" && scripts/check.sh > "$work/b.log" 2>&1) || { cat "$work/b.log"; fail "variant B: scripts/check.sh fails"; }
[ ! -e "$b/.github/workflows/docs-review.yml" ] && [ ! -e "$b/.claude/skills/docs-review" ] ||
  fail "variant B: docs-review files exist although the module is off"
grep -q '"self-hosted"' "$b/.github/workflows/docs.yml" || fail "variant B: docs.yml lacks the self-hosted default"
! grep -r -n -i 'docs-review' "$b/AGENTS.md" "$b/docs" > "$work/b-grep.log" || { cat "$work/b-grep.log"; fail "variant B: documents mention docs-review"; }
[ ! -e "$b/.github/workflows/code-review.yml" ] && [ ! -e "$b/.claude/skills/review-code" ] ||
  fail "variant B: code-review files exist although the module is off"
! grep -r -n -i 'code-review\|review-code' "$b/AGENTS.md" "$b/docs" "$b/.claude/skills" > "$work/b-grep.log" || { cat "$work/b-grep.log"; fail "variant B: documents mention code-review"; }
[ -f "$b/.claude/skills/dual-review/SKILL.md" ] || fail "variant B: the dual-review skill is missing although the module is on"

echo "== pull request description template in both variants"
# The sections of the description template (docs/contributing.md, section 3), in order; a
# description built from them, with "None" in each list section and the template's own Metrics
# tables, passes the readiness check on a change without diff.
expected=$'Summary\nAcceptance and test plan\nChecks\nAssumptions and open questions\nOwner decisions\nGate files\nMetrics\nNotes for the owner'
for v in a b; do
  d="$work/$v"
  got=$(awk '/^```markdown$/ {f=1; next} /^```$/ {f=0} f && /^## / {sub(/^## /, ""); print}' "$d/docs/contributing.md")
  [ "$got" = "$expected" ] || fail "variant $v: description template sections are '$(printf '%s' "$got" | tr '\n' '|')'"
  awk '/^```markdown$/ {f=1; next} /^```$/ {f=0} !f {next}
    /^## / {s = substr($0, 4); print $0 "\n"; if (s == "Acceptance and test plan") print "- None: no behaviour change\n"; else if (s != "Metrics") print "- None\n"; next}
    s == "Metrics" && /^\|/ {print} s == "Metrics" && /^$/ {print}' "$d/docs/contributing.md" > "$work/$v-body.md"
  (cd "$d" && scripts/check-decisions.sh --ready --base main --pr-body "$work/$v-body.md" > "$work/$v-ready.log" 2>&1) ||
    { cat "$work/$v-ready.log"; fail "variant $v: readiness rejects a description in the template's sections"; }
done

echo "== negative tests on variant A"
expect_fail() { # description, command...
  local what="$1"; shift
  if (cd "$a" && "$@" > /dev/null 2>&1); then fail "not caught: $what"; fi
  gitc "$a" checkout -q -- . && gitc "$a" clean -q -fd
}
expect_pass() {
  local what="$1"; shift
  (cd "$a" && "$@" > "$work/pass.log" 2>&1) || { cat "$work/pass.log"; fail "wrongly rejected: $what"; }
  gitc "$a" checkout -q -- . && gitc "$a" clean -q -fd
}
cat > "$work/hook-settings.json" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/project/stop/10-x.sh"}]}]}}
JSON
expect_fail "a hook command whose script is missing" bash -c 'cp "$work/hook-settings.json" .claude/settings.project.json && scripts/gen-settings.sh && scripts/check-template.sh'
expect_pass "a hook command whose script exists" bash -c 'cp "$work/hook-settings.json" .claude/settings.project.json && mkdir -p .claude/hooks/project/stop &&
  printf "#!/bin/sh\nexit 0\n" > .claude/hooks/project/stop/10-x.sh && chmod +x .claude/hooks/project/stop/10-x.sh && scripts/gen-settings.sh && scripts/check-template.sh'
expect_pass "protect-branch prints the ruleset of the default branch" bash -c 'scripts/protect-branch.sh --dry-run | node -e "const r=JSON.parse(require(\"fs\").readFileSync(0,\"utf8\")); process.exit(r.conditions.ref_name.include[0]===\"~DEFAULT_BRANCH\" && r.rules.some(x=>x.type===\"pull_request\") && r.rules.some(x=>x.type===\"non_fast_forward\") ? 0 : 1)"'
expect_fail "a link to a missing file" bash -c 'printf "# Note\n\nSee [x](docs/nope.md).\n" > note.md && node scripts/check-links.mjs'
expect_fail "a link to a missing heading of another document" bash -c 'printf "# Note\n\nSee [x](docs/testing-rules.md#no-such-heading).\n" > note.md && node scripts/check-links.mjs'
expect_fail "a link to a missing heading of the same document" bash -c 'printf "# Note\n\n## Part\n\nSee [x](#parts).\n" > note.md && node scripts/check-links.mjs'
expect_pass "links to files, headings, duplicate headings, HTML anchors, and code are fine" bash -c 'printf "# Note\n\n## Part \x60one\x60\n\n## Part \x60one\x60\n\n<a id=\"here\"></a>\n\n[a](docs/README.md) [b](#part-one-1) [c](#here) [d](docs/) [e](https://example.com/x#y) \x60[f](nope.md)\x60\n\n\x60\x60\x60\n[g](nope.md)\n\x60\x60\x60\n" > note.md && node scripts/check-links.mjs'
expect_fail "edited template-owned rules" bash -c 'echo x >> docs/documentation-rules.md && scripts/check-template.sh'
expect_fail "edited template-owned script" bash -c 'echo "# x" >> scripts/check.sh && scripts/check-template.sh'
expect_pass "edited project block" bash -c 'sed -i.bak "s/The project is/This project is/" AGENTS.md && rm AGENTS.md.bak && scripts/check-template.sh'
expect_fail "edited AGENTS.md outside the block" bash -c 'echo x >> AGENTS.md && scripts/check-template.sh'
expect_fail "removed project block end" bash -c 'grep -v "project:end" AGENTS.md > t && mv t AGENTS.md && scripts/check-template.sh'
expect_pass "a rule document over its line budget is named" bash -c 'for i in $(seq 1 200); do echo x; done >> docs/contributing.md; scripts/check-template.sh | grep -q "docs/contributing.md: [0-9]* lines; at most 200"'
expect_fail "settings.project.json changed, settings.json not regenerated" bash -c 'printf "{\"permissions\":{\"deny\":[\"Bash(rm -rf:*)\"]}}\n" > .claude/settings.project.json && scripts/check-template.sh'
expect_pass "settings.json regenerated with the project's deny rule" bash -c 'printf "{\"permissions\":{\"deny\":[\"Bash(rm -rf:*)\"]}}\n" > .claude/settings.project.json && scripts/gen-settings.sh && scripts/check-template.sh &&
  "$work/sj" "s.permissions.deny.includes(\"Bash(rm -rf:*)\") && s.permissions.deny.includes(\"Bash(git push --force*)\") && s.hooks.PreToolUse.length === 1"'
record() { printf -- '---\nstatus: %s\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' "${2:-proposed}" > "docs/decisions/$1-test.md"; }
export -f record
expect_fail "record that skips a number" bash -c 'record 0002; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_pass "record with the next number" bash -c 'record 0001; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_fail "stale decision index" bash -c 'record 0001; scripts/check-decisions.sh --base main'

echo "== merge readiness on variant A"
# body <file> <acceptance item> [<sensor table>] [<extra sections>]: a description in the
# template's sections; the change under test is the working tree of variant A against main.
sensors=$'| Sensor | Class | Found | Fixed | Limit | Declined |\n| --- | --- | --- | --- | --- | --- |\n| code-review | blocker | 1 | 1 | 0 | 0 |\n| code-review | suggestion | 2 | 1 | 1 | 0 |\n\n'
measures=$'| Measure | Value |\n| --- | --- |\n| First check.sh | fail |\n| Ralph iterations | 2 |\n| Santa rounds | 0 |\n| Owner interventions | 1 (answered a question) |\n| Files outside the scope | 0 |\n| Regression of | none |\n'
body() {
  printf '## Summary\n\n- x\n\n## Acceptance and test plan\n\n%s\n\n## Checks\n\n- x\n\n## Assumptions and open questions\n\n- limit: a code-review suggestion, left for later\n\n%s## Metrics\n\n%s%s' \
    "$2" "${4:-}" "${3-$sensors}" "$measures" > "$1"
}
row() { printf '| Sensor | Class | Found | Fixed | Limit | Declined |\n| --- | --- | --- | --- | --- | --- |\n%s\n\n' "$1"; }
body "$work/r-ok.md" '- REQ-001: `scripts/check.sh` (`variant A`); failed on the base, passes now'
body "$work/r-none.md" '- None: documentation only'
body "$work/r-missing-test.md" '- REQ-001: `tests/missing_test.sh`; passes now'
body "$work/r-no-file.md" '- REQ-001: covered by the existing tests'
body "$work/r-unanswered.md" '- None: x' "$(row '| code-review | suggestion | 2 | 1 | 0 | 0 |')"
body "$work/r-blocker-limit.md" '- None: x' "$(row '| code-review | blocker | 1 | 0 | 1 | 0 |')"
body "$work/r-bad-class.md" '- None: x' "$(row '| code-review | should | 1 | 1 | 0 | 0 |')"
body "$work/r-no-sensors.md" '- None: x' ''
printf '## Summary\n\n- x\n\n## Acceptance and test plan\n\n- None: x\n\n## Assumptions and open questions\n\n- None\n' > "$work/r-no-metrics.md"
printf '## Summary\n\n- x\n\n## Assumptions and open questions\n\n- None\n\n## Metrics\n\n%s' "$measures" > "$work/r-no-acceptance.md"
sed 's/| Santa rounds | 0 |//' "$work/r-none.md" > "$work/r-no-santa.md"
sed 's/| First check.sh | fail |/| First check.sh | maybe |/' "$work/r-none.md" > "$work/r-bad-first.md"
body "$work/r-decisions.md" '- None: x' '' $'## Owner decisions\n\n- `docs/plans/x.md`: the statement; "do it" (owner, chat, 2026-10-30)\n\n'
body "$work/r-gate.md" '- None: x' '' $'## Gate files\n\n- `scripts/checks.d/20-x.sh`: a new project check\n\n'
ready() { scripts/check-decisions.sh --ready --base main --pr-body "$1"; }
marker() { mkdir -p docs/plans && printf 'A statement. Decided by the owner, 2026-10-30.\n' >> docs/plans/x.md; }
gatefile() { mkdir -p scripts/checks.d && printf '#!/bin/sh\n' > scripts/checks.d/20-x.sh; }
classes() { scripts/check-decisions.sh --classes --base main; }
export -f ready marker gatefile classes
export work
expect_pass "description with acceptance evidence, a limit, and metrics" bash -c 'ready "$work/r-ok.md"'
expect_pass "Acceptance None with a reason, no sensor ran" bash -c 'ready "$work/r-no-sensors.md"'
expect_fail "no Acceptance section" bash -c 'ready "$work/r-no-acceptance.md"'
expect_fail "Acceptance names a test file that does not exist" bash -c 'ready "$work/r-missing-test.md"'
expect_fail "Acceptance item without a test file" bash -c 'ready "$work/r-no-file.md"'
expect_fail "no Metrics section" bash -c 'ready "$work/r-no-metrics.md"'
expect_fail "a finding counted but not answered" bash -c 'ready "$work/r-unanswered.md"'
expect_fail "a blocker recorded as a limit" bash -c 'ready "$work/r-blocker-limit.md"'
expect_fail "a class other than blocker or suggestion" bash -c 'ready "$work/r-bad-class.md"'
expect_fail "a missing measure" bash -c 'ready "$work/r-no-santa.md"'
expect_fail "a first check.sh result other than pass or fail" bash -c 'ready "$work/r-bad-first.md"'
expect_fail "an added owner marker not listed" bash -c 'marker; ready "$work/r-none.md"'
expect_pass "an added owner marker listed under Owner decisions" bash -c 'marker; ready "$work/r-decisions.md"'
expect_fail "two added markers in one file, one listed" bash -c 'marker; marker; ready "$work/r-decisions.md"'
expect_pass "a marker already on the base is not listed again" bash -c 'marker && git add -A && git -c user.name=t -c user.email=t@e commit -q -m m && ready "$work/r-none.md"; s=$?; git reset -q --hard HEAD~1; exit $s'
expect_pass "a marker in a file that is not Markdown is not a decision" bash -c 'printf "x=\"Decided by the owner, 2026-10-30.\"\n" > fixture.sh && ready "$work/r-none.md"'
expect_pass "a root-level test file in Acceptance, a version that is no path" bash -c 'echo x > calc_test.go && sed "s#^- None: documentation only#- REQ-001: \`calc_test.go\` for \`v1.2.0\`; failed on the base#" "$work/r-none.md" > "$work/r-root.md" && ready "$work/r-root.md"'
expect_fail "a measure twice" bash -c '{ cat "$work/r-none.md"; printf "| Santa rounds | 1 |\n"; } > "$work/r-twice.md" && ready "$work/r-twice.md"'
expect_pass "a change at the limit, or in generated files, does not warn" bash -c 'seq 1 400 > big.txt && seq 1 500 >> docs/decisions/README.md && ! ready "$work/r-none.md" | grep -q WARNING'
expect_fail "no Regression of row" bash -c 'grep -v "Regression of" "$work/r-none.md" > "$work/r-noreg.md" && ready "$work/r-noreg.md"'
expect_fail "a Regression of value outside its forms" bash -c 'sed "s/| Regression of | none |/| Regression of | maybe |/" "$work/r-none.md" > "$work/r-badreg.md" && ready "$work/r-badreg.md"'
expect_pass "the project takes a template deny entry out" bash -c 'printf "{\"remove\":{\"permissions\":{\"deny\":[\"Read(**/.env.*)\"]}}}\n" > .claude/settings.project.json && scripts/gen-settings.sh &&
  "$work/sj" "!s.permissions.deny.includes(\"Read(**/.env.*)\") && s.permissions.deny.includes(\"Read(**/.env)\") && !(\"remove\" in s)"'
expect_pass "a large change warns and still passes" bash -c 'seq 1 500 > big.txt && out=$(ready "$work/r-none.md") && printf "%s\n" "$out" | grep -q "WARNING: the change has 500 changed lines, more than DIFF_WARN_LINES (400)"'
expect_pass "a public contract is class high" bash -c 'mkdir -p contracts && echo x > contracts/api.yaml && classes | grep -qx "high	contracts/api.yaml"'
expect_pass "env.sh: an unset command is SKIP, a set one runs with its exit code" bash -c 'out=$(scripts/env.sh setup) && [ "$out" = "SKIP: SETUP is not set in .claude/harness.conf" ] &&
  scripts/env.sh fast > /dev/null && sed -i.bak "s/^E2E=.*/E2E=exit 3/" .claude/harness.conf && rm .claude/harness.conf.bak; scripts/env.sh e2e > /dev/null; [ $? -eq 3 ] && { scripts/env.sh nope 2> /dev/null; [ $? -eq 2 ]; }'
expect_pass "settings deny reading secrets" bash -c 'for r in "Read(**/.env)" "Read(**/.env.*)" "Read(**/*.pem)" "Read(**/*.key)"; do "$work/sj" "s.permissions.deny.includes(process.argv[1])" "$r" || exit 1; done'
expect_fail "a touched gate file not listed" bash -c 'gatefile && ready "$work/r-none.md"'
expect_pass "a touched gate file listed under Gate files" bash -c 'gatefile && ready "$work/r-gate.md"'
expect_pass "classes of the changed paths" bash -c 'gatefile && mkdir -p docs/plans src/auth && echo x > docs/plans/x.md && echo x >> docs/README.md &&
  echo x > src/app.py && echo x > src/auth/login.py && echo "{}" > .mcp.json && echo x >> docs/contributing.md && record 0001 accepted &&
  out=$(classes) && for l in "gate	scripts/checks.d/20-x.sh" "low	docs/plans/x.md" "approval	docs/README.md" "normal	src/app.py" \
    "high	src/auth/login.py" "approval	.mcp.json" "approval	docs/contributing.md" "approval	docs/decisions/0001-test.md" "review	santa"; do
    printf "%s\n" "$out" | grep -qx "$l" || { echo "missing: $l"; printf "%s\n" "$out"; exit 1; }; done'
expect_pass "review: none for documents only" bash -c 'mkdir -p docs/plans && echo x > docs/plans/x.md && classes | grep -qx "review	none"'
expect_pass "review: one for code" bash -c 'mkdir -p src && echo x > src/app.py && classes | grep -qx "review	one"'
expect_pass "review: none for a template update" bash -c 'echo x >> docs/contributing.md && echo x >> scripts/check.sh && echo " " >> .afe-answers.json && echo x >> .claude/harness.conf && classes | grep -qx "review	none"'
expect_pass "review: one for template-owned edits without an update" bash -c 'echo x >> docs/contributing.md && echo x >> scripts/check.sh && classes | grep -qx "review	one"'

echo "== metrics of merged pull requests on variant A"
# A stand-in for gh that answers `gh pr list` with three merged pull requests: two in the period,
# one of them without a Metrics section, and one before it.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || { echo "unexpected gh call: $*" >&2; exit 1; }
cat <<'JSON'
[
 {
  "number": 3,
  "createdAt": "2026-10-20T04:00:00Z",
  "mergedAt": "2026-10-20T10:00:00Z",
  "body": "## Summary\n\n- x\n\n## Metrics\n\n| Sensor | Class | Found | Fixed | Limit | Declined |\n| --- | --- | --- | --- | --- | --- |\n| code-review | blocker | 1 | 1 | 0 | 0 |\n| code-review | suggestion | 2 | 1 | 1 | 0 |\n| docs-review | suggestion | 0 | 0 | 0 | 0 |\n\n| Measure | Value |\n| --- | --- |\n| First check.sh | fail |\n| Ralph iterations | 3 |\n| Santa rounds | 0 |\n| Owner interventions | 1 (a question) |\n| Files outside the scope | 2 (a, b) |\n| Regression of | #1 |\n\n## Notes for the owner\n\n| code-review | blocker | 9 | 9 | 0 | 0 |\n"
 },
 {
  "number": 2,
  "createdAt": "2026-10-10T08:00:00Z",
  "mergedAt": "2026-10-10T10:00:00Z",
  "body": "## Summary\n\n- x\n"
 },
 {
  "number": 1,
  "mergedAt": "2026-09-01T10:00:00Z",
  "body": "## Metrics\n\n| code-review | blocker | 5 | 5 | 0 | 0 |\n"
 }
]
JSON
EOF
chmod +x "$work/bin/gh"
if out=$(cd "$a" && PATH="$work/bin:$PATH" scripts/pr-metrics.sh --since 2026-10-01 2>&1); then
  for l in 'merged pull requests since 2026-10-01: 2, with a Metrics section: 1' 'first check.sh passed: 0 of 1 pull requests' \
    'ralph iterations: total 3, median 3, max 3, in 1 pull requests' 'owner interventions: total 1, median 1, max 1, in 1 pull requests' \
    'files outside the scope: total 2, median 2, max 2, in 1 pull requests' 'regression rate: 1 of 1 pull requests repair another one' \
    'hours to merge: total 8, median 4, max 6, in 2 pull requests' \
    'sensors without a finding in the period: docs-review'; do
    printf '%s\n' "$out" | grep -q -F "$l" || { printf '%s\n' "$out"; fail "pr-metrics: no line '$l'"; }
  done
  printf '%s\n' "$out" | grep -q -E '^code-review +blocker +1 +1 +0 +0 +1$' && printf '%s\n' "$out" | grep -q -E '^code-review +suggestion +2 +1 +1 +0 +1$' &&
    ! printf '%s\n' "$out" | grep -q WARNING || { printf '%s\n' "$out"; fail "pr-metrics: wrong totals"; }
else
  printf '%s\n' "$out"; fail "pr-metrics fails"
fi
out=$(cd "$a" && PATH="$work/bin:$PATH" scripts/pr-metrics.sh --since 2026-01-01 --limit 3 2>&1)
printf '%s\n' "$out" | grep -q 'WARNING: gh listed 3 pull requests' || { printf '%s\n' "$out"; fail "pr-metrics: no warning when --limit cuts the period"; }

echo "== hooks on variant A"
hook() { # expected decision (ask|deny|allow), JSON input, directory the hook runs in, CLAUDE_PROJECT_DIR (both default: variant A)
  local out
  out=$(cd "${3:-$a}" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="${4:-$a}" "$a/.claude/hooks/protect-docs.sh" 2>&1)
  case "$1:$out" in
    ask:*'"permissionDecision":"ask"'*|deny:*'"permissionDecision":"deny"'*|allow:) ;;
    *) fail "protect hook: expected $1 for $2, got '${out:0:120}'" ;;
  esac
}
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/contributing.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/../AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"scripts/check-template.sh --write"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > \"docs/documentation-rules.md\""}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"rm .template/owned.txt"}}'
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/plans/x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cp docs/decisions/adr-template.md docs/decisions/0001-x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"scripts/check.sh 2>&1 | tee /tmp/check.log"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/contributing.md"}}'
# Class approval asks; gate, high, normal, and low paths need no prompt; so do the irreversible
# commands the hook names, and not an ordinary push.
for p in .claude/path-classes .claude/settings.project.json .claude/settings.json .mcp.json .env .claude/settings.template.json; do
  hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a/$p"'"}}'
done
for p in scripts/checks.d/20-x.sh .github/workflows/ci.yml package.json src/auth/login.py .claude/harness.conf; do
  hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a/$p"'"}}'
done
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo KEY=x >> .env.local"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo approval x >> .claude/path-classes"}}'
for c in "git push --force origin main" "git push -uf origin feature" "git push origin +feature" "git push origin --delete feature" \
  "git push origin v1.2.0" "git push origin refs/tags/x" "gh pr merge 3 --merge" "scripts/check.sh && gh release create v1.0.0" "gh repo delete example/sample --yes" \
  "git -C . push --force origin feature" "gh workflow run release.yml" "gh api -X DELETE repos/o/r/git/refs/heads/x" \
  "npm publish" "pnpm publish --access public" "cargo publish" "docker push example/app:1" "twine upload dist/*"; do
  hook ask '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# An approval line of .claude/path-classes asks even where a built-in rule would allow the edit.
printf 'approval docs/decisions/*\n' >> "$a/.claude/path-classes"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/docs/decisions/0001-new.md"}}'
gitc "$a" checkout -q -- .claude/path-classes
# The Ralph cap: a failing Stop hook blocks until RALPH_MAX_ITERATIONS failing stops, then lets the
# agent stop with the cap message, and a passing check resets the count.
gitc "$a" switch -q -c ralph
printf '#Bad heading\n' > "$a/docs/bad.md" && sed -i.bak 's/^RALPH_MAX_ITERATIONS=.*/RALPH_MAX_ITERATIONS=2/' "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
gitc "$a" add -A && gitc "$a" commit -q -m bad
stop() { (cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-check-docs.sh > "$work/stop.log" 2>&1); }
stop; [ $? -eq 2 ] || fail "ralph cap: the first failing stop does not block"
stop; [ $? -eq 0 ] && grep -q "Ralph loop cap of 2 reached" "$work/stop.log" || { cat "$work/stop.log"; fail "ralph cap: the stop at the cap still blocks"; }
stop; [ $? -eq 2 ] || fail "ralph cap: the count does not restart after the cap"
gitc "$a" switch -q main && gitc "$a" branch -q -D ralph && rm -f "$(git -C "$a" rev-parse --git-dir)"/ralph-stops-*
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"gh pr view 3 --json state"}}'
# The check after every edit: CHECK_EDIT runs on the changed file and reports a failure with exit 2.
pe() { (cd "$a" && printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"'"$1"'"}}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1); }
printf 'bad\n' > "$a/pe.txt" && printf 'ok\n' > "$a/pe-ok.txt" && cp "$a/pe.txt" "$work/outside.txt"
pe "$a/pe.txt" || fail "post-edit: runs although CHECK_EDIT is empty"
printf 'CHECK_EDIT=grep -q ok\n' >> "$a/.claude/harness.conf"
pe "$a/pe.txt"; [ $? -eq 2 ] && grep -q "CHECK_EDIT failed on pe.txt" "$work/pe.log" || { cat "$work/pe.log"; fail "post-edit: a failing CHECK_EDIT is not reported"; }
pe "$a/pe-ok.txt" || { cat "$work/pe.log"; fail "post-edit: a passing CHECK_EDIT is reported"; }
pe "$work/outside.txt" || fail "post-edit: checks a file outside the project"
printf 'CHECK_EDIT_GLOBS=src/*.py\n' >> "$a/.claude/harness.conf"
pe "$a/pe.txt" || fail "post-edit: checks a file that CHECK_EDIT_GLOBS leaves out"
gitc "$a" checkout -q -- .claude/harness.conf && rm -f "$a/pe.txt" "$a/pe-ok.txt"
# A known token format in written content or a command asks; the tokens are assembled here, so
# this file holds none.
aws="AKIA""IOSFODNN7EXAMPLE" ghp="ghp_""$(printf 'a%.0s' $(seq 1 36))" pk="-----BEGIN ""RSA PRIVATE KEY-----"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = \"'"$aws"'\""}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/src/x.js","old_string":"a","new_string":"token: '"$ghp"'"}}'
hook ask '{"tool_name":"MultiEdit","tool_input":{"file_path":"'"$a"'/k.pem","edits":[{"old_string":"a","new_string":"'"$pk"'"}]}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo '"$ghp"' > .token"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = os.environ[\"AWS_ACCESS_KEY_ID\"]"}}'
for c in "npm run build" "gh api repos/o/r/pulls" "docker build ." "git push origin main"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# A target behind `cd DIR` or `git -C DIR`, and a file an interpreter's heredoc names, resolve
# against that directory; the text of another heredoc is not read as commands.
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd docs && cat > contributing.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cd docs && echo x >> plans/x.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git -C docs checkout -- testing-rules.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd docs && python3 - <<EOF\np = \"contributing.md\"\nopen(p, \"w\").write(\"x\")\nEOF"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cat > /tmp/notes.txt <<EOF\nrm AGENTS.md\nEOF"}}'
# What the resolution must not loosen: a non-literal cd, a redirect on git -C, a shell's heredoc,
# and forms that look like a heredoc.
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd \"$REPO\" && echo x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git -C /tmp log > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"bash <<EOF\necho SECRET=1 > .env\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"grep x <<< foo\necho x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cat <<EOF | bash\necho x > AGENTS.md\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"source /dev/stdin <<EOF\necho x > AGENTS.md\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo $((1<<n))\necho x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"see <<EOF\"\necho x > AGENTS.md"}}'
# A ".." or "." in the part of the path that does not exist yet is folded before the match; a ".."
# left over climbs from the nearest existing directory, so the path may leave the repository.
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/docs/new/../README.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/./sub/../../docs/contributing.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > newdir/../AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/new/../contributing.md"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a/AGENTS.md"}}'
# A sibling worktree of the project is guarded by its own protected paths, although
# CLAUDE_PROJECT_DIR names the main checkout; the hook runs outside both. The sibling lists paths
# that the main checkout does not, so a hook that read the main checkout's lists, or resolved a
# relative Bash target against anything but the input's cwd, would allow them.
sib="$work/a-sibling"
gitc "$a" worktree add -q -b sibling "$sib"
printf 'approval sibling-only.txt\napproval gen/*\n' >> "$sib/.claude/path-classes"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/contributing.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/AGENTS.md"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/plans/x.md"}}' "$work"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/sibling-only.txt"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/sibling-only.txt"}}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > sibling-only.txt"},"cwd":"'"$sib"'"}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > docs/contributing.md"},"cwd":"/nonexistent"}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x '"$sib"'/docs/testing-rules.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/gen/new/x.txt"}}' "$work"
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/gen/new/../../../out.txt"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a-sibling/docs/contributing.md"}}' "$work"
git -C "$a" worktree remove --force "$sib" && gitc "$a" branch -q -D sibling
# A worktree inside the main checkout's directory is judged by its own repository too.
gitc "$a" worktree add -q -b inner "$a/.claude/worktrees/inner"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/.claude/worktrees/inner/docs/contributing.md"}}' "$work"
git -C "$a" worktree remove --force "$a/.claude/worktrees/inner" && gitc "$a" branch -q -D inner
# A nested repository without .template/owned.txt inside the project keeps the project's paths.
git init -q "$a/vendor/lib" && echo 'approval vendor/*' >> "$a/.claude/path-classes"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/vendor/lib/a.c"}}' "$work"
rm -rf "$a/vendor" && gitc "$a" checkout -q -- .claude/path-classes
# The session's project is guarded before its first commit, when it is not a git repository.
cp -R "$a" "$work/nogit" && rm -rf "$work/nogit/.git"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/nogit/docs/contributing.md"}}' "$work" "$work/nogit"
# Another repository without .template/owned.txt, and a path outside any repository and outside
# the session's project, are not guarded.
git init -q "$work/other" && mkdir -p "$work/other/docs" "$work/loose"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/other/docs/README.md"}}' "$work"
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$work"'/loose/AGENTS.md"}}' "$work"
gitc "$a" switch -q -c feature
printf '#Bad heading\n\n[missing](nowhere.md)\n' > "$a/docs/bad.md"
gitc "$a" add -A && gitc "$a" commit -q -m bad
(cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-check-docs.sh > /dev/null 2>&1)
[ $? -eq 2 ] || fail "stop-check-docs lets a committed broken document through"
gitc "$a" switch -q main && gitc "$a" branch -q -D feature
# A pushed feature branch must still be compared with main, not with its own upstream.
git init -q --bare "$work/origin.git"
git -C "$a" remote add origin "$work/origin.git" && gitc "$a" push -q origin main
# Once the remote has the default branch, a push to it is denied; a push of another branch is not.
for c in "git push origin main" "git push" "git push origin HEAD:main" "git -C . push origin feature:refs/heads/main"; do
  hook deny '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
gitc "$a" switch -q -c pushed && printf -- '---\nstatus: proposed\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' > "$a/docs/decisions/0001-test.md"
(cd "$a" && scripts/gen-decisions-index.sh > docs/decisions/README.md) && gitc "$a" add -A && gitc "$a" commit -q -m record
gitc "$a" push -q -u origin pushed
(cd "$a" && scripts/check-decisions.sh --ready --pr-body "$work/r-none.md" > "$work/pushed.log" 2>&1) &&
  fail "readiness on a pushed feature branch misses the proposed record"
grep -q "0001-test.md: still 'proposed'" "$work/pushed.log" || { cat "$work/pushed.log"; fail "readiness on a pushed feature branch fails for another reason"; }
gitc "$a" switch -q main && gitc "$a" branch -q -D pushed && git -C "$a" remote remove origin

echo "== smoke: a documentation-only project, every module off"
c="$work/c"
render "$c" --data docs_review=false --data code_review=false --data dual_review=false --data secret_scan=false \
  --data acceptance_check=false --data fail_without_change=false || fail "the documentation-only project does not render"
(cd "$c" && scripts/check.sh > "$work/c.log" 2>&1) || { cat "$work/c.log"; fail "documentation-only: scripts/check.sh fails"; }
[ ! -e "$c/scripts/check-acceptance.sh" ] && [ ! -e "$c/scripts/fail-without-change.sh" ] && [ ! -e "$c/.github/workflows/fail-without-change.yml" ] &&
  [ ! -e "$c/.github/workflows/secret-scan.yml" ] && ! grep -q gitleaks "$c/docs/documentation-rules.md" ||
  fail "documentation-only: module scripts exist although the modules are off"
mkdir -p "$c/docs/plans" && echo x > "$c/docs/plans/x.md"
(cd "$c" && scripts/check-decisions.sh --ready --base main --pr-body "$work/r-none.md" > "$work/c-ready.log" 2>&1 &&
  scripts/check-decisions.sh --classes --base main | grep -qx "review	none") ||
  { cat "$work/c-ready.log"; fail "documentation-only: readiness or classes fail on a document change"; }

echo "== smoke: a Python project with pytest, every module on"
d="$work/d"
render "$d" --data docs_review=true --data code_review=true --data dual_review=true \
  --data acceptance_check=true --data fail_without_change=true || fail "the Python project does not render"
(cd "$d" && scripts/check.sh > "$work/d.log" 2>&1) || { cat "$work/d.log"; fail "Python, all modules: scripts/check.sh fails (line budgets included)"; }
grep -q 'scripts/fail-without-change.sh --base "origin/$BASE_REF" --allow-pass-on-base' "$d/.github/workflows/fail-without-change.yml" ||
  fail "Python: the fail-without-change workflow does not run the driver"
# uvx provisions pytest; on a CI runner without uv, uv is installed into ~/.local/bin first.
if ! command -v uvx >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh |
    env UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 INSTALLER_NO_MODIFY_PATH=1 sh > /dev/null 2>&1 &&
    export PATH="$HOME/.local/bin:$PATH"
fi
if command -v uvx >/dev/null; then
  printf 'def add(a, b):\n    return a + b\n' > "$d/calc.py"
  mkdir -p "$d/tests" && printf 'from calc import add\n\n\ndef test_add():  # REQ-001\n    assert add(2, 3) == 5\n' > "$d/tests/test_add.py"
  sed -i.bak -e 's#^TEST_GLOBS=.*#TEST_GLOBS=tests/test_*.py#' -e 's#^FWC_TEST=.*#FWC_TEST=PYTHONPATH=. uvx --quiet pytest -q -p no:cacheprovider#' \
    "$d/.claude/harness.conf" && rm "$d/.claude/harness.conf.bak"
  gitc "$d" add -A && gitc "$d" commit -q -m "calc with add"
  gitc "$d" switch -q -c feat/mul
  printf 'def mul(a, b):\n    return a * b\n' >> "$d/calc.py"
  printf 'from calc import mul\n\n\ndef test_mul():  # REQ-002\n    assert mul(2, 3) == 6\n' > "$d/tests/test_mul.py"
  body "$d-ok.md" '- REQ-002: `tests/test_mul.py` (`test_mul`); failed on the base, passes now' ''
  body "$d-missing.md" '- REQ-003: `tests/test_mul.py` (`test_mul`); passes now' ''
  (cd "$d" && scripts/check-decisions.sh --ready --base main --pr-body "$d-ok.md" > "$work/d-ready.log" 2>&1) ||
    { cat "$work/d-ready.log"; fail "Python: readiness with the acceptance check rejects REQ-002, which a test carries"; }
  (cd "$d" && scripts/check-decisions.sh --ready --base main --pr-body "$d-missing.md" > /dev/null 2>&1) &&
    fail "Python: the acceptance check misses REQ-003, which no test carries"
  (cd "$d" && scripts/fail-without-change.sh --base main > "$work/d-fwc.log" 2>&1) && grep -q "ok: tests/test_mul.py passes with the change and fails on the base" "$work/d-fwc.log" ||
    { cat "$work/d-fwc.log"; fail "Python: fail-without-change rejects a new test that fails on the base"; }
  printf 'from calc import mul\n\n\ndef test_broken():\n    assert mul(2, 3) == 7\n' > "$d/tests/test_broken.py"
  (cd "$d" && scripts/fail-without-change.sh --base main > "$work/d-fwc0.log" 2>&1) &&
    { cat "$work/d-fwc0.log"; fail "Python: fail-without-change accepts a test that fails with the change too"; }
  grep -q "tests/test_broken.py does not pass with the change" "$work/d-fwc0.log" || { cat "$work/d-fwc0.log"; fail "Python: no reason for a test that fails with the change"; }
  rm "$d/tests/test_broken.py"
  printf '\n\ndef test_add_again():\n    assert add(1, 1) == 2\n' >> "$d/tests/test_add.py"
  (cd "$d" && scripts/fail-without-change.sh --base main > "$work/d-fwc2.log" 2>&1) &&
    { cat "$work/d-fwc2.log"; fail "Python: fail-without-change misses a changed test that passes on the base"; }
  (cd "$d" && scripts/fail-without-change.sh --base main --allow-pass-on-base > "$work/d-fwc3.log" 2>&1) ||
    { cat "$work/d-fwc3.log"; fail "Python: --allow-pass-on-base does not allow a test that passes on the base"; }
  [ "$(git -C "$d" worktree list | wc -l | tr -d ' ')" = 1 ] || fail "Python: fail-without-change leaves a worktree behind"
  gitc "$d" checkout -q -- tests/test_add.py && gitc "$d" add -A && gitc "$d" commit -q -m mul
  gitc "$d" mv tests/test_add.py tests/test_sum.py && printf '\n\ndef test_mul_sum():\n    from calc import mul\n    assert mul(2, 2) + 1 == 5\n' >> "$d/tests/test_sum.py"
  gitc "$d" add -A && gitc "$d" commit -q -m rename
  (cd "$d" && scripts/fail-without-change.sh --base main > "$work/d-fwc4.log" 2>&1) && grep -q "ok: tests/test_sum.py passes with the change and fails on the base" "$work/d-fwc4.log" ||
    { cat "$work/d-fwc4.log"; fail "Python: fail-without-change misses a renamed test file"; }
else
  echo "SKIP: uv could not be installed, so pytest cannot be provisioned for the Python smoke test"
fi

echo "== update keeps project content"
# pkg <dir> <version>: a copy of this package at another version, sharing node_modules.
pkg() {
  mkdir -p "$1" && cp -R bin src template package.json "$1/" && ln -s "$root/node_modules" "$1/node_modules"
  node -e 'const f=process.argv[1]+"/package.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.version=process.argv[2];fs.writeFileSync(f,JSON.stringify(p))' "$1" "$2"
}
sample=(--defaults --quiet --data project_name=sample --data 'project_description=A sample project.' --data github_repo=example/sample)
tpl="$work/tpl"
pkg "$tpl" 0.0.1
u="$work/u"
node "$tpl/bin/create-afe-project.js" "$u" "${sample[@]}" > "$work/u.log" 2>&1 || { cat "$work/u.log"; fail "update test: create fails"; }
git -C "$u" init -q -b main
awk '{print} /<!-- project:start -->/ {print "Project line one."; print "Project line two."}' "$u/AGENTS.md" > "$work/ag" && mv "$work/ag" "$u/AGENTS.md"
echo "Project note." >> "$u/README.md"
mkdir -p "$u/scripts/checks.d" && printf '#!/usr/bin/env bash\necho project check\n' > "$u/scripts/checks.d/10-sample.sh" && chmod +x "$u/scripts/checks.d/10-sample.sh"
rm "$u/.claude/harness.conf"
gitc "$u" add -A && gitc "$u" commit -q -m init
printf '\nA line added by the next template version.\n' >> "$tpl/template/docs/contributing.md.jinja"
sed -i.bak '/^scripts\/pr-metrics.sh$/d' "$tpl/template/.template/owned.txt.jinja" && rm "$tpl/template/scripts/pr-metrics.sh" "$tpl/template/.template/owned.txt.jinja.bak"
node -e 'const f=process.argv[1],fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.version="0.0.2";fs.writeFileSync(f,JSON.stringify(p))' "$tpl/package.json"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/up.log" 2>&1) || { cat "$work/up.log"; fail "update test: update fails"; }
grep -q 'Project line two.' "$u/AGENTS.md" || fail "update test: the project block was lost"
grep -q 'Project note.' "$u/README.md" || fail "update test: the seeded README was overwritten"
[ -f "$u/.claude/harness.conf" ] || fail "update test: a missing seeded file was not created"
[ -x "$u/scripts/checks.d/10-sample.sh" ] || fail "update test: the project check was lost"
grep -q 'added by the next template version' "$u/docs/contributing.md" || fail "update test: the template change did not arrive"
[ ! -e "$u/scripts/pr-metrics.sh" ] || fail "update test: a file the template no longer owns was kept"
grep -q '"_version": "0.0.2"' "$u/.afe-answers.json" || fail "update test: the answers file does not record 0.0.2"
(cd "$u" && scripts/check-template.sh > "$work/ut.log" 2>&1) || { cat "$work/ut.log"; fail "update test: template check fails after the update"; }
gitc "$u" add -A && gitc "$u" commit -q -m update
echo "local edit" >> "$u/docs/testing-rules.md" && echo "dirty" > "$u/scratch.txt"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > /dev/null 2>&1) &&
  fail "update test: update runs on a working tree with uncommitted changes"
rm "$u/scratch.txt" && gitc "$u" commit -q -am "edit a template-owned file"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/up2.log" 2>&1) || { cat "$work/up2.log"; fail "update test: second update fails"; }
grep -q 'Replaced local edits of template-owned files.*docs/testing-rules.md' "$work/up2.log" && ! grep -q 'local edit' "$u/docs/testing-rules.md" ||
  { cat "$work/up2.log"; fail "update test: a local edit of a template-owned file is not replaced and reported"; }
pkg "$work/new" 0.0.3
(cd "$u" && node "$work/new/bin/create-afe-project.js" update --defaults --allow-dirty > /dev/null 2>&1) || fail "update test: update to a newer version fails"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults --allow-dirty > "$work/down.log" 2>&1) &&
  fail "update test: an older package downgrades the project"

echo "== update converts a project generated by Copier"
v="$work/v"
node "$tpl/bin/create-afe-project.js" "$v" "${sample[@]}" --no-git --data ci_runner=self-hosted > /dev/null 2>&1 || fail "adoption test: create fails"
rm "$v/.afe-answers.json"
printf '# Written by copier\n_commit: v0.0.1\n_src_path: https://github.com/xandronak/agent-docs-template\nci_runner: self-hosted\ndocs_review: false\ngithub_repo: example/sample\nproject_description: '"'"'A sample\n    project.'"'"'\nproject_name: sample\nself_hosted_labels: '"'"'["self-hosted","linux"]'"'"'\n' > "$v/.copier-answers.yml"
(cd "$v" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/v.log" 2>&1) || { cat "$work/v.log"; fail "adoption test: update fails"; }
[ ! -e "$v/.copier-answers.yml" ] && grep -q '"project_description": "A sample project."' "$v/.afe-answers.json" &&
  grep -q '"self_hosted_labels": "\[\\"self-hosted\\",\\"linux\\"\]"' "$v/.afe-answers.json" && [ ! -e "$v/.github/workflows/docs-review.yml" ] ||
  { cat "$v/.afe-answers.json"; fail "adoption test: the Copier answers are not converted"; }

# The 0.5.0 migration: an update from a release before 0.5.0 that seeded .claude/protected-paths
# keeps its glob lines as class approval in .claude/path-classes.
mt="$work/mtpl"
pkg "$mt" 0.4.9 && printf '# Protected paths.\n' > "$mt/template/.claude/protected-paths"
mu="$work/mu"
node "$mt/bin/create-afe-project.js" "$mu" "${sample[@]}" > "$work/mu.log" 2>&1 || { cat "$work/mu.log"; fail "migration test: create fails"; }
git -C "$mu" init -q -b main && printf 'vendor/*\n' >> "$mu/.claude/protected-paths" && gitc "$mu" add -A && gitc "$mu" commit -q -m init
rm "$mt/template/.claude/protected-paths"
node -e 'const f=process.argv[1],fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.version="0.5.0";fs.writeFileSync(f,JSON.stringify(p))' "$mt/package.json"
(cd "$mu" && node "$mt/bin/create-afe-project.js" update --defaults > "$work/mup.log" 2>&1) || { cat "$work/mup.log"; fail "migration test: update fails"; }
grep -qx 'approval vendor/\*' "$mu/.claude/path-classes" && [ ! -e "$mu/.claude/protected-paths" ] && [ ! -e "$mu/.claude/protected-paths.pre-0.5" ] ||
  fail "migration test: the glob lines of .claude/protected-paths are not class approval in .claude/path-classes"

echo "== this repository matches template/"
self="$work/self"
cli "$self" --defaults --quiet --data-file .afe-answers.json > "$work/self.log" 2>&1 ||
  { cat "$work/self.log"; fail "this repository's answers do not render"; }
strip() { awk '$0=="<!-- project:start -->" {print; s=1; next} $0=="<!-- project:end -->" {s=0} !s' "$1"; }
while IFS= read -r p; do
  case "$p" in ''|'#'*) continue ;; esac
  if [ "$p" = AGENTS.md ]; then
    [ "$(strip AGENTS.md)" = "$(strip "$self/AGENTS.md")" ] || fail "AGENTS.md differs from template/; run scripts/sync-self.sh"
  else
    cmp -s "$p" "$self/$p" || fail "$p differs from template/; run scripts/sync-self.sh"
  fi
done < "$self/.template/owned.txt"

if [ "$failures" -gt 0 ]; then
  echo "== template tests failed: $failures"
  exit 1
fi
echo "== template tests passed"
