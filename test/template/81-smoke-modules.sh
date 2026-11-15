# Smoke test: a project with every module on, rendered into $d, and the action pins of every
# variant. Needs $a, $b, $c from 10-, 13-, and 80-*.sh, and no_stale_refs from 15-no-stale-refs.sh.
echo "== smoke: every module on; every action pinned"
d="$work/d"
render "$d" --data code_review=true --data secret_scan=true || fail "the project with every module does not render"
(cd "$d" && scripts/check.sh > "$work/d.log" 2>&1) || { cat "$work/d.log"; fail "all modules: scripts/check.sh fails (line budgets included)"; }
# No generated file of $c or $d names a removed file (no_stale_refs of 15-no-stale-refs.sh).
no_stale_refs "$c" C
no_stale_refs "$d" D
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
(cd "$d" && scripts/protect-branch.sh --dry-run) | node -e 'const p = JSON.parse(require("fs").readFileSync(0, "utf8"));
  process.exit(p.ruleset.rules.find((x) => x.type === "required_status_checks").parameters.required_status_checks.map((c) => c.context).join() === "check" ? 0 : 1)' ||
  fail "all modules: protect-branch does not require exactly the check job"
