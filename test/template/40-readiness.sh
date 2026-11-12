# Merge readiness and path classes on variant A. Needs $a from 10-variant-a.sh and expect_fail,
# expect_pass, record from 30-negative.sh; defines body and writes $work/r-none.md for later files.
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
expect_pass "dependency updates, pre-commit hooks, task runners, and tool versions are class gate" bash -c 'fs=".github/dependabot.yml .github/dependabot.yaml
  renovate.json renovate.json5 .github/renovate.json .renovaterc .renovaterc.json .pre-commit-config.yaml Makefile svc/Makefile makefile GNUmakefile
  build/common.mk justfile svc/justfile Justfile .justfile Taskfile.yml Taskfile.yaml svc/Taskfile.yml Taskfile.dist.yml taskfile.yml taskfile.dist.yaml
  svc/makefile svc/GNUmakefile svc/a/x.mk svc/Justfile svc/.justfile svc/Taskfile.dist.yml svc/taskfile.yml svc/taskfile.dist.yaml
  .tool-versions mise.toml mise.local.toml .mise.toml .mise.ci.toml mise/config.toml .mise/config.toml .config/mise.toml .config/mise/config.toml";
  . scripts/lib/classes.sh && for f in $fs; do [ "$(class_of "$f" HEAD)" = gate ] || { echo "not gate: $f"; exit 1; }; done &&
  mkdir -p svc && echo x > Makefile && echo x > svc/justfile && out=$(classes) && printf "%s\n" "$out" | grep -qx "gate	Makefile" &&
  printf "%s\n" "$out" | grep -qx "gate	svc/justfile"'
expect_pass "the manifests, lock files, toolchain, and tool configuration of every ecosystem are class gate" bash -c 'fs="package.json svc/package.json
  npm-shrinkwrap.json pnpm-workspace.yaml .yarnrc.yml bun.lock bun.lockb deno.json deno.jsonc deno.lock .npmrc .nvmrc .node-version
  pyproject.toml svc/pyproject.toml setup.py setup.cfg requirements-dev.in svc/requirements.txt Pipfile Pipfile.lock .python-version
  go.mod svc/go.mod svc/go.sum go.work go.work.sum .golangci.yml .golangci.yaml crates/x/Cargo.toml .cargo/config.toml rust-toolchain
  rust-toolchain.toml clippy.toml pom.xml svc/pom.xml build.gradle sub/build.gradle.kts settings.gradle.kts gradle.properties
  gradle.lockfile svc/gradle.lockfile gradle/libs.versions.toml gradle/wrapper/gradle-wrapper.properties gradlew gradlew.bat
  .mvn/wrapper/maven-wrapper.properties mvnw Gemfile Gemfile.lock svc/Gemfile.lock app.gemspec .ruby-version .rubocop.yml
  composer.json composer.lock svc/composer.json phpunit.xml.dist phpstan.neon src/App/App.csproj src/F/F.fsproj Directory.Packages.props
  src/Directory.Build.props packages.lock.json src/App/packages.lock.json nuget.config NuGet.Config .config/dotnet-tools.json
  global.json Package.swift svc/Package.swift Package.resolved Podfile Podfile.lock .swiftlint.yml pubspec.yaml pubspec.lock
  app/pubspec.lock melos.yaml analysis_options.yaml src/App/App.vbproj svc/Gemfile svc/composer.lock app/pubspec.yaml
  svc/Package.resolved svc/build.gradle .golangci.toml
  web/package-lock.json web/npm-shrinkwrap.json web/pnpm-lock.yaml web/yarn.lock web/.yarnrc.yml web/bun.lock web/bun.lockb
  web/deno.json web/deno.jsonc web/deno.lock web/.npmrc web/.nvmrc web/.node-version svc/setup.py svc/setup.cfg svc/uv.lock
  svc/poetry.lock svc/requirements-dev.in svc/Pipfile svc/Pipfile.lock svc/.python-version crates/x/Cargo.lock
  crates/x/.cargo/config.toml crates/x/rust-toolchain crates/x/rust-toolchain.toml svc/settings.gradle.kts svc/gradle.properties
  svc/gradle/libs.versions.toml svc/.ruby-version src/nuget.config src/NuGet.Config src/.config/dotnet-tools.json ios/Podfile
  ios/Podfile.lock"; . scripts/lib/classes.sh &&
  for f in $fs; do [ "$(class_of "$f" HEAD)" = gate ] || { echo "not gate: $f"; exit 1; }; done &&
  for f in src/main.go src/App/Program.cs lib/app.rb src/main.rs app/models/user.py locales/en/global.json; do
    [ "$(class_of "$f" HEAD)" = normal ] || { echo "not normal: $f"; exit 1; }; done'
expect_pass "classes of the changed paths" bash -c 'gatefile && mkdir -p docs/plans src/auth && echo x > docs/plans/x.md && echo x >> docs/README.md &&
  echo x > src/app.py && echo x > src/auth/login.py && echo "{}" > .mcp.json && echo x >> docs/contributing.md && record 0001 accepted &&
  out=$(classes) && for l in "gate	scripts/checks.d/20-x.sh" "low	docs/plans/x.md" "approval	docs/README.md" "normal	src/app.py" \
    "high	src/auth/login.py" "approval	.mcp.json" "approval	docs/contributing.md" "approval	docs/decisions/0001-test.md" "review	santa"; do
    printf "%s\n" "$out" | grep -qx "$l" || { echo "missing: $l"; printf "%s\n" "$out"; exit 1; }; done'
expect_pass "review: none for documents only" bash -c 'mkdir -p docs/plans && echo x > docs/plans/x.md && classes | grep -qx "review	none"'
expect_pass "review: one for code" bash -c 'mkdir -p src && echo x > src/app.py && classes | grep -qx "review	one"'
expect_pass "review: none for a template update" bash -c 'echo x >> docs/contributing.md && echo x >> scripts/check.sh && echo " " >> .afe-answers.json && echo x >> .claude/harness.conf && classes | grep -qx "review	none"'
expect_pass "review: one for template-owned edits without an update" bash -c 'echo x >> docs/contributing.md && echo x >> scripts/check.sh && classes | grep -qx "review	one"'
