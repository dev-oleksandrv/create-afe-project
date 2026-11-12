# The 3.0.0 migration of an update from 2.1.0. Needs pkg and $sample from 90-update.sh.
# The 2.1.0 fixture is created by the package of the release commit, 761f382, which needs the full
# history of this repository (CI checks out with fetch-depth 0).
echo "== update from 2.1.0 applies the 3.0.0 migration"
p210="$work/p210"
mkdir -p "$p210" && git -C "$root" archive 761f382 bin src template package.json | tar -x -C "$p210" &&
  ln -s "$root/node_modules" "$p210/node_modules" || fail "3.0.0 migration test: commit 761f382 (2.1.0) is not in this repository"
p300="$work/p300"
pkg "$p300" 3.0.0
# Both removed modules on, and the 2.1.0 defaults of the others: code_review on, acceptance_check
# off, the opposite of the 3.0.0 defaults.
m="$work/m210"
node "$p210/bin/create-afe-project.js" "$m" "${sample[@]}" --data dual_review=true > "$work/m210.log" 2>&1 ||
  { cat "$work/m210.log"; fail "3.0.0 migration test: create at 2.1.0 fails"; }
# The same project after the owner changed its path classes and caps.
mc="$work/mc210"
cp -R "$m" "$mc" && echo 'gate own/*' >> "$mc/.claude/path-classes" &&
  sed -i.bak 's/^RALPH_MAX_ITERATIONS=5$/RALPH_MAX_ITERATIONS=4/; s/^REVIEW_MAX_ROUNDS=3$/REVIEW_MAX_ROUNDS=5/' "$mc/.claude/harness.conf" &&
  rm "$mc/.claude/harness.conf.bak" && gitc "$mc" commit -q -am "own path classes and caps"
(cd "$m" && node "$p300/bin/create-afe-project.js" update --defaults > "$work/m300.log" 2>&1) ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: the update from 2.1.0 fails"; }
# A 2.x answers file as --data-file names the removed questions; they are ignored.
(cd "$mc" && node "$p300/bin/create-afe-project.js" update --defaults --data-file .afe-answers.json > "$work/mc300.log" 2>&1) ||
  { cat "$work/mc300.log"; fail "3.0.0 migration test: the update from 2.1.0 with the 2.x answers file as --data-file fails"; }
grep -q 'Migrations run: 3.0.0' "$work/m300.log" || { cat "$work/m300.log"; fail "3.0.0 migration test: the migration does not run"; }

cmp -s "$m/.claude/path-classes" "$root/template/.claude/path-classes" && ! grep -q 'Warning: .claude/path-classes' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: a default 2.1.0 .claude/path-classes is not replaced with the 3.0.0 default"; }
grep -qx 'gate own/\*' "$mc/.claude/path-classes" && grep -q '^approval ' "$mc/.claude/path-classes" &&
  grep -q 'Warning: .claude/path-classes is not a default.*remove its approval lines.*trim the ecosystem gate blocks' "$work/mc300.log" ||
  { cat "$work/mc300.log"; fail "3.0.0 migration test: a changed .claude/path-classes is replaced, or the change by hand is not reported"; }

grep -qx 'RALPH_MAX_ITERATIONS=2' "$m/.claude/harness.conf" && grep -qx 'REVIEW_MAX_ROUNDS=2' "$m/.claude/harness.conf" ||
  fail "3.0.0 migration test: the 2.x caps 5 and 3 in .claude/harness.conf are not set to 2"
grep -qx 'RALPH_MAX_ITERATIONS=4' "$mc/.claude/harness.conf" && grep -qx 'REVIEW_MAX_ROUNDS=5' "$mc/.claude/harness.conf" ||
  fail "3.0.0 migration test: caps the project set in .claude/harness.conf are not kept"

[ -f "$m/docs/README.md" ] && grep -q '^# Documentation map' "$m/docs/README.md" &&
  grep -q 'Warning: docs/README.md is no longer maintained by the template' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: docs/README.md is not kept, or the update does not warn about it"; }

for d in "$m" "$mc"; do
  ! grep -q 'docs_review\|dual_review' "$d/.afe-answers.json" && grep -q '"code_review": true' "$d/.afe-answers.json" &&
    grep -q '"acceptance_check": false' "$d/.afe-answers.json" && grep -q '"_version": "3.0.0"' "$d/.afe-answers.json" ||
    { cat "$d/.afe-answers.json"; fail "3.0.0 migration test: $d: the answers keep docs_review or dual_review, or lose code_review or acceptance_check"; }
done
grep -q 'not carried over.*docs_review, dual_review' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: the dropped docs_review and dual_review answers are not reported"; }

for f in docs/documentation-rules.md docs/contributing.md docs/testing-rules.md scripts/pr-metrics.sh \
  .claude/hooks/protect-docs.sh .claude/hooks/stop-check-docs.sh .claude/hooks/stop-check-decisions.sh \
  .claude/hooks/stop-check-template.sh .claude/hooks/stop-check-fast.sh .claude/hooks/stop-run-project-hooks.sh \
  .claude/skills/docs-review .claude/skills/dual-review .github/workflows/docs-review.yml .github/workflows/docs.yml; do
  [ ! -e "$m/$f" ] || fail "3.0.0 migration test: $f, no longer template-owned, is kept"
done

# The owner follows the warning and updates the map; then the updated project passes its checks.
printf '# Documentation map\n\nRules for agents: [AGENTS.md](../AGENTS.md).\n' > "$m/docs/README.md"
(cd "$m" && scripts/check.sh > "$work/m300check.log" 2>&1) ||
  { tail -40 "$work/m300check.log"; fail "3.0.0 migration test: the project updated from 2.1.0 fails scripts/check.sh"; }
