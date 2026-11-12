# The readiness step of decisions.yml on a pull request that a workflow opened. Needs $a from
# 10-variant-a.sh, $b from 13-variant-b.sh, and record from 30-negative.sh.
# A pull request that a workflow opened with GITHUB_TOKEN (a generated release pull request) has
# a generated description: the readiness step of the workflow, run as written, checks only its
# decision records, and the AI reviews skip it; a person's empty description still fails.
awk '/name: description ready/ {f = 1} f && /run: \|/ {r = 1; next} r && /^[[:space:]]*$/ {print ""; next}
     r && !/^          / {exit} r {sub(/^          /, ""); print}' "$a/.github/workflows/decisions.yml" > "$work/ready.sh"
[ -s "$work/ready.sh" ] || fail "decisions.yml: no readiness step to run"
# The step runs as GitHub runs it on Linux: `bash -e` by default, with pipefail for `shell: bash`.
ready_shell=$(awk '/name: description ready/ {f = 1; next} f && /^      - / {exit} f && /^        shell:/ {print $2; exit}' "$a/.github/workflows/decisions.yml")
case "$ready_shell" in
  bash) ready_sh=(bash --noprofile --norc -eo pipefail) ;;
  *) ready_sh=(bash -e) ;;
esac
ready() { (cd "$a" && BASE_REF=ready-base RUNNER_TEMP="$work" PR_BODY= PR_AUTHOR="$1" "${ready_sh[@]}" "$work/ready.sh" > "$work/ready.log" 2>&1); }
git -C "$a" update-ref refs/remotes/origin/ready-base HEAD
ready 'github-actions[bot]' && grep -q "opened by a workflow: its generated description is not checked" "$work/ready.log" ||
  { cat "$work/ready.log"; fail "readiness: checks the generated description of a pull request a workflow opened"; }
# A failing --classes call fails the step; the pipe into awk does not hide it.
cp "$a/scripts/check-decisions.sh" "$work/check-decisions.keep" &&
  printf '#!/usr/bin/env bash\ncase " $* " in *" --classes "*) echo classes-failed >&2; exit 3 ;; esac\n' > "$a/scripts/check-decisions.sh"
ready 'github-actions[bot]'; [ $? -ne 0 ] && grep -q classes-failed "$work/ready.log" ||
  { cat "$work/ready.log"; fail "readiness: a failing --classes call of a pull request a workflow opened passes the step"; }
cp "$work/check-decisions.keep" "$a/scripts/check-decisions.sh"
ready someone; [ $? -eq 1 ] && grep -q "no '## Summary' section" "$work/ready.log" ||
  { cat "$work/ready.log"; fail "readiness: does not fail the empty description of a pull request a person opened on its sections"; }
grep -qF 'only for a pull request that `github-actions[bot]` opened, and does not block' "$a/docs/contributing.md" &&
  grep -qF 'opens or leaves draft, except one that `github-actions[bot]` opened;' "$b/docs/contributing.md" ||
  fail "contributing.md does not state the exemption of a pull request a workflow opened"
(cd "$a" && mkdir -p src && echo x > src/app.py && mkdir -p scripts/checks.d && echo x > scripts/checks.d/20-x.sh && record 0001 proposed && scripts/gen-decisions-index.sh > docs/decisions/README.md)
ready 'github-actions[bot]'; [ $? -ne 0 ] && grep -q "still 'proposed'" "$work/ready.log" && grep -q "class gate, for the owner's review: scripts/checks.d/20-x.sh" "$work/ready.log" ||
  { cat "$work/ready.log"; fail "readiness: a pull request a workflow opened skips its decision records or hides its gate files"; }
gitc "$a" checkout -q -- . && gitc "$a" clean -q -fd && git -C "$a" update-ref -d refs/remotes/origin/ready-base
for w in code-review; do
  [ -f "$b/.github/workflows/$w.yml" ] || continue
  grep -qF "if: \${{ !github.event.pull_request.draft && github.event.pull_request.user.login != 'github-actions[bot]' }}" "$b/.github/workflows/$w.yml" ||
    fail "$w.yml: reviews a pull request that a workflow opened"
done
