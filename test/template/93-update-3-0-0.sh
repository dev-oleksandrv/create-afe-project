# The update of a 2.1.0 project to 5.0.0, which runs the migrations 3.0.0, 4.0.0, and 5.0.0, also
# when a failing migration interrupts the update once. Needs pkg, failing_pkg, and $sample from
# 90-update.sh.
# The 2.1.0 fixture is created by the package of the release commit, 761f382, which needs the full
# history of this repository (CI checks out with fetch-depth 0).
echo "== update from 2.1.0 applies the migrations up to 5.0.0"
p210="$work/p210"
mkdir -p "$p210" && git -C "$root" archive 761f382 bin src template package.json | tar -x -C "$p210" &&
  ln -s "$root/node_modules" "$p210/node_modules" || fail "3.0.0 migration test: commit 761f382 (2.1.0) is not in this repository"
p300="$work/p300"
pkg "$p300" 5.0.0
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
# A project file of mc names a removed document: its own decision record.
printf -- '---\nstatus: proposed\ndate: 2026-11-01\n---\n\n# Own choice\n\nWe follow docs/contributing.md.\n' \
  > "$mc/docs/decisions/0001-own-choice.md" && gitc "$mc" add docs/decisions/0001-own-choice.md && gitc "$mc" commit -q -m "own decision"
# The same project after the owner configured its setup, kept the default caps, and removed every
# reference to a removed file, docs/README.md with them: a clean project.
ms="$work/ms210"
cp -R "$m" "$ms" && sed -i.bak 's/^SETUP=$/SETUP=make setup/' "$ms/.claude/harness.conf" &&
  for f in README.md .gitignore .claude/harness.conf; do
    sed -i.bak -E '/docs\/(documentation-rules|contributing|testing-rules|README)[.]md|stop-check-|dual-review/d' "$ms/$f" && rm "$ms/$f.bak"
  done && gitc "$ms" rm -q docs/README.md && gitc "$ms" commit -q -am "own setup, no references to removed files"
mi="$work/mi210"
cp -R "$m" "$mi"
# The same project with both seeded files, still 2.1.0 defaults, as symbolic links to files outside
# it: the migration writes neither, and says so for each.
ml="$work/ml210"
cp -R "$m" "$ml" && mkdir -p "$work/ml-out" && for f in path-classes harness.conf; do
  mv "$ml/.claude/$f" "$work/ml-out/$f" && cp "$work/ml-out/$f" "$work/ml-out/$f.orig" && ln -s "$work/ml-out/$f" "$ml/.claude/$f"
done && gitc "$ml" add -A && gitc "$ml" commit -q -m "seeded files as links"
(cd "$ml" && node "$p300/bin/create-afe-project.js" update --defaults > "$work/ml300.log" 2>&1) ||
  { cat "$work/ml300.log"; fail "3.0.0 migration test: the update with seeded files as symbolic links fails"; }
for f in path-classes harness.conf; do
  cmp -s "$work/ml-out/$f" "$work/ml-out/$f.orig" && [ -L "$ml/.claude/$f" ] ||
    { cat "$work/ml300.log"; fail "3.0.0 migration test: the migration writes through, or removes, the symbolic link .claude/$f"; }
done
grep -q "^Warning: .claude/harness.conf is a symbolic link, so the update does not migrate it: " "$work/ml300.log" &&
  grep -q "^Warning: .claude/path-classes or .claude/risky-paths is a symbolic link, so the update does not migrate it: " "$work/ml300.log" ||
  { cat "$work/ml300.log"; fail "3.0.0 migration test: the update does not say that it left a seeded file that is a symbolic link"; }
(cd "$m" && node "$p300/bin/create-afe-project.js" update --defaults > "$work/m300.log" 2>&1) ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: the update from 2.1.0 fails"; }
# A migration after 3.0.0's fails once: the version stays 2.1.0, and the second run runs the 3.0.0
# migration again and ends where the update without a failure ended.
failing_pkg "$work/p300f" 5.0.0 "$work/fail-once-300" && touch "$work/fail-once-300"
(cd "$mi" && node "$work/p300f/bin/create-afe-project.js" update --defaults > "$work/mi1.log" 2>&1) &&
  fail "3.0.0 migration test: the update with a failing migration succeeds"
grep -q '"_version": "2.1.0"' "$mi/.afe-answers.json" && grep -q 'run the same update again with --allow-dirty' "$work/mi1.log" ||
  { cat "$work/mi1.log" "$mi/.afe-answers.json"; fail "3.0.0 migration test: a failed migration records the new version, or the message does not say how to resume"; }
(cd "$mi" && node "$work/p300f/bin/create-afe-project.js" update --defaults --allow-dirty > "$work/mi2.log" 2>&1) ||
  { cat "$work/mi2.log"; fail "3.0.0 migration test: the second run after a failed migration fails"; }
grep -q 'Migrations run: 3.0.0' "$work/mi2.log" && diff -r -x .git "$m" "$mi" > "$work/mi.diff" ||
  { cat "$work/mi2.log" "$work/mi.diff"; fail "3.0.0 migration test: the second run does not run the 3.0.0 migration again, or ends elsewhere than an update without a failure"; }
# A 2.x answers file as --data-file names the removed questions; they are ignored.
(cd "$mc" && node "$p300/bin/create-afe-project.js" update --defaults --data-file .afe-answers.json > "$work/mc300.log" 2>&1) ||
  { cat "$work/mc300.log"; fail "3.0.0 migration test: the update from 2.1.0 with the 2.x answers file as --data-file fails"; }
(cd "$ms" && node "$p300/bin/create-afe-project.js" update --defaults > "$work/ms300.log" 2>&1) ||
  { cat "$work/ms300.log"; fail "3.0.0 migration test: the update from 2.1.0 of the configured project fails"; }
grep -q 'Migrations run: 3.0.0' "$work/m300.log" || { cat "$work/m300.log"; fail "3.0.0 migration test: the migration does not run"; }

# 5.0.0: the path classes become the risky paths. The high globs of 2.1.0 are the defaults, so the
# file equals the template's; the classes file is gone, and the update says so.
for d in "$m" "$mc"; do
  [ ! -e "$d/.claude/path-classes" ] && cmp -s "$d/.claude/risky-paths" "$root/template/.claude/risky-paths" ||
    fail "5.0.0 migration test: $d: .claude/path-classes is kept, or .claude/risky-paths is not the default with its high globs"
done
grep -q '^Warning: .claude/path-classes is replaced by .claude/risky-paths' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "5.0.0 migration test: the update does not say that the path classes are replaced"; }

# A default 2.1.0 .claude/harness.conf becomes the 3.0.0 default, byte for byte as a fresh render.
node "$p300/bin/create-afe-project.js" "$work/f300" "${sample[@]}" > "$work/f300.log" 2>&1 || { cat "$work/f300.log"; fail "3.0.0 migration test: create at 3.0.0 fails"; }
cmp -s "$m/.claude/harness.conf" "$work/f300/.claude/harness.conf" ||
  { diff "$work/f300/.claude/harness.conf" "$m/.claude/harness.conf"; fail "3.0.0 migration test: a default 2.1.0 .claude/harness.conf is not replaced whole with the 3.0.0 default"; }
# A configured .claude/harness.conf keeps its values; the keys that nothing reads are reported.
grep -qx 'SETUP=make setup' "$ms/.claude/harness.conf" &&
  grep -q '^Warning: .claude/harness.conf sets RALPH_MAX_ITERATIONS, REVIEW_MAX_ROUNDS.*which 5.0.0 no longer reads' "$work/ms300.log" ||
  { cat "$ms/.claude/harness.conf" "$work/ms300.log"; fail "5.0.0 migration test: a configured .claude/harness.conf loses its SETUP, or its unread keys are not reported"; }
! grep -q 'RALPH_MAX_ITERATIONS' "$m/.claude/harness.conf" && ! grep -q '^Warning: .claude/harness.conf sets' "$work/m300.log" ||
  fail "5.0.0 migration test: a default .claude/harness.conf keeps a removed key, or is reported"
grep -qx 'RALPH_MAX_ITERATIONS=4' "$mc/.claude/harness.conf" && grep -qx 'REVIEW_MAX_ROUNDS=5' "$mc/.claude/harness.conf" ||
  fail "3.0.0 migration test: a .claude/harness.conf the project changed is not kept as it is"

[ -f "$m/docs/README.md" ] && grep -q '^# Documentation map' "$m/docs/README.md" &&
  grep -q 'Warning: docs/README.md is no longer maintained by the template' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: docs/README.md is not kept, or the update does not warn about it"; }

# Each project file that names a removed file gets one warning, and docs/README.md only its own.
for f in README.md docs/decisions/0001-own-choice.md; do
  [ "$(grep -c "^Warning: $f names removed files (.*docs/contributing[.]md.*); update or remove those references[.]$" "$work/mc300.log")" = 1 ] ||
    { cat "$work/mc300.log"; fail "3.0.0 migration test: $f names docs/contributing.md, and the update does not warn about it exactly once"; }
done
[ "$(grep -c '^Warning: docs/README.md' "$work/mc300.log")" = 1 ] && [ "$(grep -c '^Warning: .claude/path-classes' "$work/mc300.log")" = 1 ] ||
  { cat "$work/mc300.log"; fail "3.0.0 migration test: docs/README.md or .claude/path-classes is warned about more than once"; }
! grep 'names removed files' "$work/ms300.log" | grep -q -E 'documentation-rules|contributing[.]md|testing-rules|docs/README' &&
  grep -q 'Migrations run: 3.0.0, 4.0.0, 5.0.0' "$work/ms300.log" ||
  { cat "$work/ms300.log"; fail "3.0.0 migration test: a project without references to the files 3.0.0 removed gets a warning about them, or a migration does not run"; }
# Every update to 5.0.0 names the ruleset step, which only the owner can take.
grep -q '^Warning: scripts/protect-branch.sh: the ruleset of 4.x requires the check integrity' "$work/ms300.log" ||
  { cat "$work/ms300.log"; fail "5.0.0 migration test: the update does not name the ruleset step"; }

for d in "$m" "$mc" "$ms"; do
  ! grep -q 'docs_review\|dual_review' "$d/.afe-answers.json" && grep -q '"code_review": true' "$d/.afe-answers.json" &&
    ! grep -q 'acceptance_check\|fail_without_change' "$d/.afe-answers.json" && grep -q '"_version": "5.0.0"' "$d/.afe-answers.json" ||
    { cat "$d/.afe-answers.json"; fail "3.0.0 migration test: $d: the answers keep a removed question, or lose code_review"; }
done
grep -q 'not carried over.*docs_review, dual_review' "$work/m300.log" ||
  { cat "$work/m300.log"; fail "3.0.0 migration test: the dropped docs_review and dual_review answers are not reported"; }

for f in docs/documentation-rules.md docs/contributing.md docs/testing-rules.md scripts/pr-metrics.sh \
  .claude/hooks/protect-docs.sh .claude/hooks/stop-check-docs.sh .claude/hooks/stop-check-decisions.sh \
  .claude/hooks/stop-check-template.sh .claude/hooks/stop-check-fast.sh .claude/hooks/stop-run-project-hooks.sh \
  .claude/skills/docs-review .claude/skills/dual-review .github/workflows/docs-review.yml .github/workflows/docs.yml \
  .claude/skills/create-pr .claude/hooks/stop-dispatch.sh scripts/check-decisions.sh .github/workflows/decisions.yml; do
  [ ! -e "$m/$f" ] || fail "3.0.0 migration test: $f, no longer template-owned, is kept"
done

# The owner follows the warning and updates the map; then the updated project passes its checks.
printf '# Documentation map\n\nRules for agents: [AGENTS.md](../AGENTS.md).\n' > "$m/docs/README.md"
(cd "$m" && scripts/check.sh > "$work/m300check.log" 2>&1) ||
  { tail -40 "$work/m300check.log"; fail "3.0.0 migration test: the project updated from 2.1.0 fails scripts/check.sh"; }
