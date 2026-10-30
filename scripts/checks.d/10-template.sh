#!/usr/bin/env bash
# Template tests (docs/maintaining.md, section 3): render the template in two variants and run the
# generated project's checks, prove that the checks catch violations, and confirm that this
# repository's own template-owned files match template/.
set -uo pipefail
cd "$(dirname "$0")/../.."
# This check provisions Copier itself (documentation-rules.md, section 9): through uvx, and on a
# CI runner without uv by installing uv into ~/.local/bin first.
if ! command -v copier >/dev/null; then
  if ! command -v uvx >/dev/null; then
    echo "== installing uv for the template tests"
    curl -LsSf https://astral.sh/uv/install.sh |
      env UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 INSTALLER_NO_MODIFY_PATH=1 sh > /dev/null 2>&1 ||
      { echo "FAIL: copier is missing and uv could not be installed"; exit 1; }
    export PATH="$HOME/.local/bin:$PATH"
  fi
  copier() { uvx --quiet --from 'copier>=9.4' copier "$@"; }
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
gitc() { git -C "$1" -c user.name=test -c user.email=test@example.com "${@:2}"; }

render() {
  local d="$1"; shift
  copier copy -q --trust --defaults --vcs-ref HEAD --data project_name=sample \
    --data 'project_description=A sample project.' --data github_repo=example/sample "$@" . "$d" \
    > "$work/render.log" 2>&1 || { cat "$work/render.log"; return 1; }
  git -C "$d" init -q -b main && gitc "$d" add -A && gitc "$d" commit -q -m init
}

echo "== variant A: GitHub-hosted runner, the default modules (docs-review and code-review on, dual review off)"
a="$work/a"
render "$a" || fail "variant A does not render"
(cd "$a" && scripts/check.sh > "$work/a.log" 2>&1) || { cat "$work/a.log"; fail "variant A: scripts/check.sh fails"; }
grep -q 'ubuntu-latest' "$a/.github/workflows/docs.yml" || fail "variant A: docs.yml lacks the GitHub-hosted default"
[ -f "$a/.github/workflows/code-review.yml" ] && [ -f "$a/.claude/skills/review-code/SKILL.md" ] ||
  fail "variant A: code-review files are missing although the module is on"
[ ! -e "$a/.claude/skills/dual-review" ] || fail "variant A: dual-review files exist although the module is off"
! grep -r -n -i 'dual.review' "$a/AGENTS.md" "$a/docs" "$a/.claude/skills" > "$work/a-grep.log" || { cat "$work/a-grep.log"; fail "variant A: documents mention the dual review"; }

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
# description built from them, with an unlabelled bullet under "Owner decisions to confirm", passes
# the readiness check, which reads only "Assumptions and open questions" of a description.
expected=$'Summary\nTest plan\nChecks\nAssumptions and open questions\nOwner decisions to confirm\nNotes for the owner'
for v in a b; do
  d="$work/$v"
  got=$(awk '/^```markdown$/ {f=1; next} /^```$/ {f=0} f && /^## / {sub(/^## /, ""); print}' "$d/docs/contributing.md")
  [ "$got" = "$expected" ] || fail "variant $v: description template sections are '$(printf '%s' "$got" | tr '\n' '|')'"
  printf '%s\n' "$got" | awk '{print "## " $0 "\n"} $0 == "Owner decisions to confirm" {print "- `docs/x.md`: a statement; instruction quoted\n"; next} {print "- None\n"}' > "$work/$v-body.md"
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
expect_fail "edited template-owned rules" bash -c 'echo x >> docs/documentation-rules.md && scripts/check-template.sh'
expect_fail "edited template-owned script" bash -c 'echo "# x" >> scripts/check.sh && scripts/check-template.sh'
expect_pass "edited project block" bash -c 'sed -i.bak "s/The project is/This project is/" AGENTS.md && rm AGENTS.md.bak && scripts/check-template.sh'
expect_fail "edited AGENTS.md outside the block" bash -c 'echo x >> AGENTS.md && scripts/check-template.sh'
expect_fail "removed project block end" bash -c 'grep -v "project:end" AGENTS.md > t && mv t AGENTS.md && scripts/check-template.sh'
record() { printf -- '---\nstatus: proposed\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' > "docs/decisions/$1-test.md"; }
export -f record
expect_fail "record that skips a number" bash -c 'record 0002; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_pass "record with the next number" bash -c 'record 0001; scripts/gen-decisions-index.sh > docs/decisions/README.md; scripts/check-decisions.sh --base main'
expect_fail "stale decision index" bash -c 'record 0001; scripts/check-decisions.sh --base main'

echo "== hooks on variant A"
hook() { # expected decision (ask|allow), JSON input, directory the hook runs in, CLAUDE_PROJECT_DIR (both default: variant A)
  local out
  out=$(cd "${3:-$a}" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="${4:-$a}" "$a/.claude/hooks/protect-docs.sh" 2>&1)
  case "$1:$out" in
    ask:*'"permissionDecision":"ask"'*|allow:) ;;
    *) fail "protect hook: expected $1 for $2, got '${out:0:120}'" ;;
  esac
}
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/contributing.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/../AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"scripts/check-template.sh --write"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > \"docs/documentation-rules.md\""}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"rm .template/owned.txt"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/.claude/protected-paths"}}'
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/plans/x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cp docs/decisions/adr-template.md docs/decisions/0001-x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"scripts/check.sh 2>&1 | tee /tmp/check.log"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/contributing.md"}}'
# A sibling worktree of the project is guarded by its own protected paths, although
# CLAUDE_PROJECT_DIR names the main checkout; the hook runs outside both. The sibling lists paths
# that the main checkout does not, so a hook that read the main checkout's lists, or resolved a
# relative Bash target against anything but the input's cwd, would allow them.
sib="$work/a-sibling"
gitc "$a" worktree add -q -b sibling "$sib"
printf 'sibling-only.txt\ngen/*\n' >> "$sib/.claude/protected-paths"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/contributing.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/AGENTS.md"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/plans/x.md"}}' "$work"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/sibling-only.txt"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/sibling-only.txt"}}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > sibling-only.txt"},"cwd":"'"$sib"'"}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > docs/contributing.md"},"cwd":"/nonexistent"}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x '"$sib"'/docs/testing-rules.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/gen/new/x.txt"}}' "$work"
git -C "$a" worktree remove --force "$sib" && gitc "$a" branch -q -D sibling
# A worktree inside the main checkout's directory is judged by its own repository too.
gitc "$a" worktree add -q -b inner "$a/.claude/worktrees/inner"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/.claude/worktrees/inner/docs/contributing.md"}}' "$work"
git -C "$a" worktree remove --force "$a/.claude/worktrees/inner" && gitc "$a" branch -q -D inner
# A nested repository without .template/owned.txt inside the project keeps the project's paths.
git init -q "$a/vendor/lib" && echo 'vendor/*' >> "$a/.claude/protected-paths"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/vendor/lib/a.c"}}' "$work"
rm -rf "$a/vendor" && gitc "$a" checkout -q -- .claude/protected-paths
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
gitc "$a" switch -q -c pushed && printf -- '---\nstatus: proposed\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' > "$a/docs/decisions/0001-test.md"
(cd "$a" && scripts/gen-decisions-index.sh > docs/decisions/README.md) && gitc "$a" add -A && gitc "$a" commit -q -m record
gitc "$a" push -q -u origin pushed
printf '## Summary\n\n- x\n\n## Assumptions and open questions\n\n- None\n' > "$work/body.md"
(cd "$a" && scripts/check-decisions.sh --ready --pr-body "$work/body.md" > /dev/null 2>&1) &&
  fail "readiness on a pushed feature branch misses the proposed record"
gitc "$a" switch -q main && gitc "$a" branch -q -D pushed && git -C "$a" remote remove origin

echo "== copier update keeps project content"
tpl="$work/tpl"
mkdir -p "$tpl" && cp -R copier.yml template "$tpl/"
git -C "$tpl" init -q -b main && gitc "$tpl" add -A && gitc "$tpl" commit -q -m v1 && gitc "$tpl" tag v0.0.1
u="$work/u"
copier copy -q --trust --defaults --vcs-ref v0.0.1 --data project_name=sample \
  --data 'project_description=A sample project.' --data github_repo=example/sample "$tpl" "$u" > "$work/u.log" 2>&1 ||
  { cat "$work/u.log"; fail "update test: copy fails"; }
git -C "$u" init -q -b main
awk '{print} /<!-- project:start -->/ {print "Project line one."; print "Project line two."}' "$u/AGENTS.md" > "$work/ag" && mv "$work/ag" "$u/AGENTS.md"
echo "Project note." >> "$u/README.md"
mkdir -p "$u/scripts/checks.d" && printf '#!/usr/bin/env bash\necho project check\n' > "$u/scripts/checks.d/10-sample.sh" && chmod +x "$u/scripts/checks.d/10-sample.sh"
gitc "$u" add -A && gitc "$u" commit -q -m init
printf '\nA line added by the next template version.\n' >> "$tpl/template/docs/contributing.md.jinja"
gitc "$tpl" commit -q -am v2 && gitc "$tpl" tag v0.0.2
(cd "$u" && copier update -q --trust --defaults --vcs-ref v0.0.2 > "$work/up.log" 2>&1) || { cat "$work/up.log"; fail "update test: update fails"; }
grep -q 'Project line two.' "$u/AGENTS.md" || fail "update test: the project block was lost"
grep -q 'Project note.' "$u/README.md" || fail "update test: the seeded README was overwritten"
[ -x "$u/scripts/checks.d/10-sample.sh" ] || fail "update test: the project check was lost"
grep -q 'added by the next template version' "$u/docs/contributing.md" || fail "update test: the template change did not arrive"
grep -q '_commit: v0.0.2' "$u/.copier-answers.yml" || fail "update test: the answers file does not record v0.0.2"
(cd "$u" && scripts/check-template.sh > "$work/ut.log" 2>&1) || { cat "$work/ut.log"; fail "update test: template check fails after the update"; }

echo "== this repository matches template/"
self="$work/self"
grep -v -E '^(_|#)' .copier-answers.yml > "$work/answers.yml"
copier copy -q --trust --defaults --vcs-ref HEAD --data-file "$work/answers.yml" . "$self" > "$work/self.log" 2>&1 ||
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
