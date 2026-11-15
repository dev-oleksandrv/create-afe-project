# The update of a project of the published 4.0.0 package to 5.0.0: the process files are removed,
# the high globs of .claude/path-classes move to .claude/risky-paths, the generated decision index
# goes, the steps by hand are warnings, the checks pass, and a second update changes nothing.
# Needs pkg and $sample from 90-update.sh. The 4.0.0 package is built from its release commit,
# 9c2ebf5, which needs the full history of this repository, as in 93-update-3-0-0.sh.
echo "== update from 4.0.0 to 5.0.0"
p4="$work/p4"
mkdir -p "$p4" && git -C "$root" archive 9c2ebf5 bin src template package.json | tar -x -C "$p4" &&
  ln -s "$root/node_modules" "$p4/node_modules" || fail "5.0.0 update test: commit 9c2ebf5 (4.0.0) is not in this repository"
p5="$work/p5"
pkg "$p5" 5.0.0
q="$work/q400"
node "$p4/bin/create-afe-project.js" "$q" "${sample[@]}" --data code_review=true > "$work/q400.log" 2>&1 || { cat "$work/q400.log"; fail "5.0.0 update test: create at 4.0.0 fails"; }
# The project has path classes of its own, a decision record, and a check that calls the full
# check with a flag that 5.0.0 removes.
printf 'high own/secure/*\ngate own/config.json\n' >> "$q/.claude/path-classes"
printf -- '---\nstatus: accepted\ndate: 2026-11-01\ndecision-makers: owner\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Own choice\n' > "$q/docs/decisions/0001-own-choice.md"
(cd "$q" && scripts/gen-decisions-index.sh > docs/decisions/README.md)
mkdir -p "$q/tools" && printf '#!/usr/bin/env bash\nscripts/check.sh --if-changed\n' > "$q/tools/precommit.sh"
gitc "$q" add -A && gitc "$q" commit -q -m "own classes, a record, a caller of --if-changed"

(cd "$q" && node "$p5/bin/create-afe-project.js" update --defaults > "$work/q-up.log" 2>&1) || { cat "$work/q-up.log"; fail "5.0.0 update test: the update fails"; }
grep -q 'Migrations run: 5.0.0' "$work/q-up.log" && grep -q '"_version": "5.0.0"' "$q/.afe-answers.json" ||
  { cat "$work/q-up.log"; fail "5.0.0 update test: the 5.0.0 migration does not run, or the version is not recorded"; }
for f in .claude/skills/create-pr .claude/skills/review .claude/hooks/stop-dispatch.sh .claude/path-classes scripts/check-decisions.sh \
  scripts/gen-decisions-index.sh scripts/lib/classes.sh scripts/lib/stamp.sh scripts/check-acceptance.sh .github/workflows/decisions.yml \
  docs/decisions/README.md; do
  [ ! -e "$q/$f" ] || fail "5.0.0 update test: $f is kept"
done
[ -f "$q/docs/decisions/0001-own-choice.md" ] && [ -f "$q/.claude/skills/review-code/SKILL.md" ] || fail "5.0.0 update test: the project's record or the review-code module is lost"
# The risky paths: the defaults, then the project's own high glob; no gate glob.
grep -qx 'own/secure/\*' "$q/.claude/risky-paths" && grep -qx '\*auth/\*' "$q/.claude/risky-paths" && ! grep -q 'own/config.json' "$q/.claude/risky-paths" &&
  [ "$(grep -c -x '\*auth/\*' "$q/.claude/risky-paths")" = 1 ] ||
  { cat "$q/.claude/risky-paths"; fail "5.0.0 update test: .claude/risky-paths does not hold the defaults once and the project's high glob"; }
for w in '.claude/path-classes is replaced by .claude/risky-paths' 'docs/decisions/README.md, the generated decision index, is removed' \
  '.claude/harness.conf sets RALPH_MAX_ITERATIONS, REVIEW_MAX_ROUNDS, DIFF_WARN_LINES, ID_PATTERN, TEST_GLOBS, FWC_TOOLCHAIN_GLOBS, FWC_TEST, which 5.0.0 no longer reads' \
  'scripts/protect-branch.sh: the ruleset of 4.x requires the check integrity' \
  'tools/precommit.sh names removed files (check.sh --if-changed)'; do
  grep -q -F -- "Warning: $w" "$work/q-up.log" || { cat "$work/q-up.log"; fail "5.0.0 update test: no warning '$w'"; }
done
(cd "$q" && "$work/sj" '!s.hooks.Stop') || fail "5.0.0 update test: the generated settings still register the Stop hook"
(cd "$q" && scripts/check.sh > "$work/q-check.log" 2>&1) || { tail -40 "$work/q-check.log"; fail "5.0.0 update test: the updated project fails scripts/check.sh"; }
# Once updated, the same update again changes nothing: the migration is safe to run twice.
gitc "$q" add -A && gitc "$q" commit -q -m update
(cd "$q" && node "$p5/bin/create-afe-project.js" update --defaults --allow-dirty > "$work/q-again.log" 2>&1) && [ -z "$(git -C "$q" status --porcelain)" ] ||
  { cat "$work/q-again.log"; git -C "$q" status --short | head; fail "5.0.0 update test: a second update changes the project"; }
