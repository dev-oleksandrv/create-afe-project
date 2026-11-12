# Negative tests: the checks of variant A catch violations. Needs $a from 10-variant-a.sh; defines
# expect_fail, expect_pass, and record, which later files use.
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
expect_pass "protect-branch prints the settings and the ruleset of the default branch" bash -c 'scripts/protect-branch.sh --dry-run | node -e "const p=JSON.parse(require(\"fs\").readFileSync(0,\"utf8\")), r=p.ruleset, pr=r.rules.find(x=>x.type===\"pull_request\"), sc=r.rules.find(x=>x.type===\"required_status_checks\");
  process.exit(r.conditions.ref_name.include[0]===\"~DEFAULT_BRANCH\" && r.rules.some(x=>x.type===\"non_fast_forward\") && r.rules.some(x=>x.type===\"deletion\") && pr.parameters.allowed_merge_methods.join()===\"merge\" &&
  sc.parameters.required_status_checks.map(c=>c.context).join()===\"check,integrity\" && p.repository.allow_merge_commit===true && p.repository.allow_squash_merge===false && p.repository.allow_rebase_merge===false &&
  p.repository.delete_branch_on_merge===true && p.security.security_and_analysis.secret_scanning_push_protection.status===\"enabled\" ? 0 : 1)"'
expect_pass "protect-branch --require-base refuses without the fail-without-change workflow" bash -c '! scripts/protect-branch.sh --dry-run --require-base 2> err.log &&
  grep -q "needs the fail-without-change workflow" err.log'
# A live run against a stand-in for gh: the repository settings, then secret scanning, then the
# ruleset. On an HTTP error the stand-in answers as gh does: the response body on stdout,
# "gh: <message> (HTTP <status>)" on stderr, and exit code 1.
mkdir -p "$work/ghpb" && cat > "$work/ghpb/gh" <<'GH'
#!/usr/bin/env bash
in=; case " $* " in *" --input - "*) in=$(cat) ;; esac
printf '%s | %s\n' "$*" "$in" >> "$work/ghpb.log"
err() { printf '{"message":"%s","status":"%s"}' "$2" "$1"; printf 'gh: %s (HTTP %s)\n' "$2" "$1" >&2; exit 1; }
case "$*" in "repo view"*) echo example/sample; exit 0 ;; esac
# The list of rulesets. GHPB_LIST=403 refuses it as GitHub Free does for a private repository,
# GHPB_LIST=404 as not found; GHPB_LIST=500 fails otherwise. With GHPB_PARENT set, an organisation ruleset of the same name,
# id 9, comes first unless the query asks for the repository's own (includes_parents=false). With
# GHPB_RULESET set, the ruleset exists as id 7: on the first page, or with "page2" on the second,
# which only --paginate reads.
case "$*" in *"repos/example/sample/rulesets --jq"*|*"repos/example/sample/rulesets?"*" --jq"*)
  case "${GHPB_LIST:-}" in
    403) err 403 "Upgrade to GitHub Pro or make this repository public to enable this feature." ;;
    404) err 404 "Not Found" ;;
    500) err 500 "Server Error" ;;
  esac
  case "$*" in *includes_parents=false*) ;; *) [ -z "${GHPB_PARENT:-}" ] || echo 9 ;; esac
  case "${GHPB_RULESET:-}:$*" in :*) ;; page2:*--paginate*) echo 7 ;; page2:*) ;; *) echo 7 ;; esac
  exit 0 ;;
esac
# Reading ruleset 7: it requires check and integrity, with GHPB_RULESET=base also base; with
# "fail", reading it fails.
case "$*:${GHPB_RULESET:-}" in
  "api repos/example/sample/rulesets/7 --jq"*:fail) err 502 "Bad Gateway" ;;
  "api repos/example/sample/rulesets/7 --jq"*:base) printf 'check\nintegrity\nbase\n'; exit 0 ;;
  "api repos/example/sample/rulesets/7 --jq"*) printf 'check\nintegrity\n'; exit 0 ;;
esac
# Secret scanning: refused by the plan by default, with HTTP 422, or with GHPB_SECRET=upgrade with
# HTTP 403; GHPB_SECRET=admin refuses it for a missing permission, =invalid rejects the payload,
# =network fails without a response, =ok enables it.
case "$in:${GHPB_SECRET:-}" in
  *security_and_analysis*:ok) ;;
  *security_and_analysis*:upgrade) err 403 "Upgrade to GitHub Pro or make this repository public to enable this feature." ;;
  *security_and_analysis*:admin) err 403 "Must have admin rights to Repository." ;;
  *security_and_analysis*:invalid) err 422 "Validation Failed" ;;
  *security_and_analysis*:network) echo "error connecting to api.github.com" >&2; exit 1 ;;
  *security_and_analysis*) err 422 "Secret scanning is not available for this repository." ;;
esac
exit 0
GH
chmod +x "$work/ghpb/gh"
expect_pass "protect-branch applies the settings, goes on past secret scanning the plan refuses, and creates the ruleset" bash -c 'rm -f "$work/ghpb.log";
  out=$(PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) && printf "%s\n" "$out" | grep -q "secret scanning and push protection not set" &&
  printf "%s\n" "$out" | grep -q "Secret scanning is not available for this repository" &&
  grep -q "^api --method PATCH repos/example/sample --input - | .*\"allow_squash_merge\":false.*\"delete_branch_on_merge\":true" "$work/ghpb.log" &&
  grep -q "^api --method POST repos/example/sample/rulesets --input - | .*\"allowed_merge_methods\":\[\"merge\"\]" "$work/ghpb.log" &&
  [ "$(grep -c "^api --method PATCH repos/example/sample " "$work/ghpb.log")" = 2 ] || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch goes on past secret scanning the plan refuses with HTTP 403" bash -c 'rm -f "$work/ghpb.log";
  out=$(GHPB_SECRET=upgrade PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) && printf "%s\n" "$out" | grep -q "secret scanning and push protection not set" &&
  grep -q "^api --method POST repos/example/sample/rulesets " "$work/ghpb.log" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch still applies the ruleset, then fails naming secret scanning, when it fails for a reason other than the plan" bash -c 'for e in admin invalid network; do rm -f "$work/ghpb.log";
  GHPB_SECRET=$e PATH="$work/ghpb:$PATH" scripts/protect-branch.sh > out.log 2>&1; code=$?;
  [ $code = 1 ] && grep -q "cannot enable secret scanning" out.log && { [ $e = network ] || grep -q "(HTTP 4" out.log; } &&
  grep -q "^api --method POST repos/example/sample/rulesets --input - | .*\"allowed_merge_methods\":\[\"merge\"\]" "$work/ghpb.log" &&
  grep -q "created the ruleset" out.log && tail -n 1 out.log | grep -q "secret scanning" || { echo "case $e, exit $code:"; cat out.log; cat "$work/ghpb.log"; exit 1; }; done'
expect_pass "protect-branch names a failed secret scanning when the plan then offers no rulesets" bash -c 'rm -f "$work/ghpb.log";
  out=$(GHPB_LIST=403 GHPB_SECRET=admin PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1); code=$?;
  [ $code = 1 ] && printf "%s\n" "$out" | grep -q "rulesets are not available" && printf "%s\n" "$out" | tail -n 1 | grep -q "secret scanning" || { echo "exit $code:"; printf "%s\n" "$out"; exit 1; }'
expect_pass "protect-branch ends without error after the settings when the plan offers no rulesets" bash -c 'for l in 403 404; do rm -f "$work/ghpb.log";
  out=$(GHPB_LIST=$l GHPB_SECRET=ok PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) &&
  printf "%s\n" "$out" | grep -q "rulesets are not available" && printf "%s\n" "$out" | grep -q "rests on the owner and review" &&
  printf "%s\n" "$out" | grep -q "secret scanning and push protection on" &&
  grep -q "^api --method PATCH repos/example/sample --input - | .*\"delete_branch_on_merge\":true" "$work/ghpb.log" &&
  ! grep -Eq "^api --method (PUT|POST) " "$work/ghpb.log" || { echo "case $l:"; printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }; done'
expect_pass "protect-branch fails with the gh output when listing the rulesets fails otherwise" bash -c 'rm -f "$work/ghpb.log";
  ! GHPB_LIST=500 PATH="$work/ghpb:$PATH" scripts/protect-branch.sh > out.log 2>&1 && grep -q "Server Error (HTTP 500)" out.log &&
  ! grep -q "rulesets are not available" out.log && ! grep -Eq "^api --method (PUT|POST) " "$work/ghpb.log" || { cat out.log; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch finds its ruleset on a later page of the list" bash -c 'rm -f "$work/ghpb.log";
  out=$(GHPB_RULESET=page2 PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) &&
  grep -q "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" && ! grep -q "^api --method POST " "$work/ghpb.log" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch updates the repository ruleset, not one of the same name inherited from the organisation" bash -c 'rm -f "$work/ghpb.log";
  out=$(GHPB_PARENT=1 GHPB_RULESET=1 PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) &&
  grep -q "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" && ! grep -q "rulesets/9" "$work/ghpb.log" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch keeps a required base check when it updates the ruleset" bash -c 'rm -f "$work/ghpb.log"; touch .github/workflows/fail-without-change.yml;
  out=$(GHPB_RULESET=base PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) && printf "%s\n" "$out" | grep -q "requires \`base\`: kept" &&
  grep -q "^api --method PUT repos/example/sample/rulesets/7 --input - | .*{\"context\":\"base\"}" "$work/ghpb.log" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch drops a required base check that no workflow reports" bash -c 'rm -f "$work/ghpb.log";
  out=$(GHPB_RULESET=base PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) && printf "%s\n" "$out" | grep -q "which no workflow of this project reports: dropped" &&
  grep "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" | grep -q "{\"context\":\"integrity\"}" &&
  ! grep "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" | grep -q "{\"context\":\"base\"}" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch adds no base check to a ruleset without one" bash -c 'rm -f "$work/ghpb.log"; touch .github/workflows/fail-without-change.yml;
  out=$(GHPB_RULESET=1 PATH="$work/ghpb:$PATH" scripts/protect-branch.sh 2>&1) && ! printf "%s\n" "$out" | grep -q "requires \`base\`" &&
  grep "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" | grep -q "{\"context\":\"integrity\"}" &&
  ! grep "^api --method PUT repos/example/sample/rulesets/7 " "$work/ghpb.log" | grep -q "{\"context\":\"base\"}" || { printf "%s\n" "$out"; cat "$work/ghpb.log"; exit 1; }'
expect_pass "protect-branch stops, changing no ruleset, when it cannot read the existing one" bash -c 'rm -f "$work/ghpb.log";
  ! GHPB_RULESET=fail PATH="$work/ghpb:$PATH" scripts/protect-branch.sh > out.log 2>&1 && grep -q "cannot read the ruleset" out.log &&
  ! grep -q "rulesets/7 --input" "$work/ghpb.log" || { cat out.log; cat "$work/ghpb.log"; exit 1; }'
expect_fail "a link to a missing file" bash -c 'printf "# Note\n\nSee [x](docs/nope.md).\n" > note.md && node scripts/check-links.mjs'
expect_fail "a link to a missing heading of another document" bash -c 'printf "# Note\n\nSee [x](AGENTS.md#no-such-heading).\n" > note.md && node scripts/check-links.mjs'
expect_fail "a link to a missing heading of the same document" bash -c 'printf "# Note\n\n## Part\n\nSee [x](#parts).\n" > note.md && node scripts/check-links.mjs'
expect_pass "links to files, headings, duplicate headings, HTML anchors, and code are fine" bash -c 'printf "# Note\n\n## Part \x60one\x60\n\n## Part \x60one\x60\n\n<a id=\"here\"></a>\n\n[a](AGENTS.md) [b](#part-one-1) [c](#here) [d](docs/) [e](https://example.com/x#y) \x60[f](nope.md)\x60\n\n\x60\x60\x60\n[g](nope.md)\n\x60\x60\x60\n" > note.md && node scripts/check-links.mjs'
expect_fail "edited template-owned document" bash -c 'echo x >> docs/decisions/adr-template.md && scripts/check-template.sh'
expect_fail "edited template-owned script" bash -c 'echo "# x" >> scripts/check.sh && scripts/check-template.sh'
expect_pass "edited project block" bash -c 'sed -i.bak "s/The project is/This project is/" AGENTS.md && rm AGENTS.md.bak && scripts/check-template.sh'
expect_fail "edited AGENTS.md outside the block" bash -c 'echo x >> AGENTS.md && scripts/check-template.sh'
expect_fail "removed project block end" bash -c 'grep -v "project:end" AGENTS.md > t && mv t AGENTS.md && scripts/check-template.sh'
expect_pass "a project block over its line budget is named" bash -c 'awk "{print} /<!-- project:start -->/ {for (i = 0; i < 11; i++) print \"x\"}" AGENTS.md > t && mv t AGENTS.md;
  scripts/check-template.sh | grep -q "AGENTS.md: the project block has 1[0-9] lines; at most 10"'
expect_pass "no line budget for any other document" bash -c 'for f in $(git ls-files "docs/*.md"); do seq 1 300 >> "$f"; done; ! scripts/check-template.sh | grep -q " lines; at most [0-9]* (a template defect)"'
expect_fail "settings.project.json changed, settings.json not regenerated" bash -c 'printf "{\"permissions\":{\"deny\":[\"Bash(rm -rf:*)\"]}}\n" > .claude/settings.project.json && scripts/check-template.sh'
expect_pass "settings.json regenerated with the project's deny rule" bash -c 'printf "{\"permissions\":{\"deny\":[\"Bash(rm -rf:*)\"]}}\n" > .claude/settings.project.json && scripts/gen-settings.sh && scripts/check-template.sh &&
  "$work/sj" "s.permissions.deny.includes(\"Bash(rm -rf:*)\") && s.permissions.deny.includes(\"Bash(git push --force*)\") && s.hooks.PreToolUse.length === 1"'
record() { printf -- '---\nstatus: %s\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' "${2:-proposed}" > "docs/decisions/$1-test.md"; }
export -f record
expect_fail "record that skips a number" bash -c 'record 0002; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_pass "record with the next number" bash -c 'record 0001; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_fail "stale decision index" bash -c 'record 0001; scripts/check-decisions.sh --base main'
