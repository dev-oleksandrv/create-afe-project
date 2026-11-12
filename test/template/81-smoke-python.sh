# Smoke test: a Python project with pytest and every module on, rendered into $d. Needs $a, $b, $c
# from 10-, 13-, and 80-*.sh, and body from 40-readiness.sh.
echo "== smoke: a Python project with pytest, every module on"
d="$work/d"
render "$d" --data docs_review=true --data code_review=true --data dual_review=true \
  --data acceptance_check=true --data fail_without_change=true || fail "the Python project does not render"
(cd "$d" && scripts/check.sh > "$work/d.log" 2>&1) || { cat "$work/d.log"; fail "Python, all modules: scripts/check.sh fails (line budgets included)"; }
grep -q 'scripts/fail-without-change.sh --base "origin/$BASE_REF" --allow-pass-on-base' "$d/.github/workflows/fail-without-change.yml" ||
  fail "Python: the fail-without-change workflow does not run the driver"
# Every action of every workflow, in each variant and in this repository, is pinned to a full
# 40-character commit SHA with its release as a comment (owner/repo@<sha> # v1.2.3), never to a
# tag, which can move; the review jobs hold CLAUDE_CODE_OAUTH_TOKEN. A project without a workflow
# file or a uses: line fails, so the test cannot pass on nothing.
for p in "$a" "$b" "$c" "$d" "$root"; do
  grep -H 'uses:' "$p"/.github/workflows/*.yml "$p"/.github/workflows/*.yaml > "$work/uses.log" 2>/dev/null
  [ -s "$work/uses.log" ] || fail "$p: no uses: line in any workflow; the pin test checks nothing"
  ! grep -v -E 'uses: +[^ @]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "$work/uses.log" > "$work/pin.log" ||
    { cat "$work/pin.log"; fail "$p: a workflow uses an action without a commit SHA and its # v<version> comment"; }
done
(cd "$d" && scripts/protect-branch.sh --dry-run --require-base) | node -e 'const p = JSON.parse(require("fs").readFileSync(0, "utf8"));
  process.exit(p.ruleset.rules.find((x) => x.type === "required_status_checks").parameters.required_status_checks.map((c) => c.context).join() === "check,integrity,base" ? 0 : 1)' ||
  fail "Python: protect-branch --require-base does not require the base job"
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
