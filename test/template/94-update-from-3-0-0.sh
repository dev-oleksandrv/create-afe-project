# The update of a project of the published 3.0.0 package to this working tree: the steps by hand
# of 4.0.0 as warnings where they apply, a local edit as a warning before it is replaced, the
# template check passing, an update interrupted by a failing migration that a second run
# completes with the same result, and a second update that changes nothing. Needs pkg,
# failing_pkg, and $sample from 90-update.sh. The 3.0.0 package is built from its release commit,
# 0c470b1, which needs the full history of this repository, as in 93-update-3-0-0.sh.
echo "== update from 3.0.0 reports the steps by hand of 4.0.0"
p3="$work/p3"
mkdir -p "$p3" && git -C "$root" archive 0c470b1 bin src template package.json | tar -x -C "$p3" &&
  ln -s "$root/node_modules" "$p3/node_modules" || fail "3.0.0 update test: commit 0c470b1 (3.0.0) is not in this repository"
here=$(node -p 'require("./package.json").version')
t="$work/t300"
node "$p3/bin/create-afe-project.js" "$t" "${sample[@]}" > "$work/t300.log" 2>&1 || { cat "$work/t300.log"; fail "3.0.0 update test: create at 3.0.0 fails"; }
# The project has a Stop hook of its own, which 3.x ran, and a local edit of a template-owned
# file; its .claude/harness.conf is the 3.0.0 default, with FWC_INSTALL and FWC_CLASSIFIER.
mkdir -p "$t/.claude/hooks/project/stop" && printf '#!/usr/bin/env bash\nexit 0\n' > "$t/.claude/hooks/project/stop/10-own.sh" &&
  chmod +x "$t/.claude/hooks/project/stop/10-own.sh" && echo "A local edit." >> "$t/.claude/rules/docs.md" &&
  gitc "$t" add -A && gitc "$t" commit -q -m "own Stop hook, local edit"
# The same project without the hook, the edit, and the two keys.
tc="$work/tc300"
cp -R "$t" "$tc" && gitc "$tc" rm -q -r .claude/hooks/project && gitc "$tc" checkout -q HEAD~1 -- .claude/rules/docs.md &&
  sed -i.bak -E '/^(FWC_INSTALL|FWC_CLASSIFIER)=/d' "$tc/.claude/harness.conf" && rm "$tc/.claude/harness.conf.bak" &&
  gitc "$tc" commit -q -am "no 3.x leftovers"
ti="$work/ti300"
cp -R "$t" "$ti"

(cd "$t" && cli update --defaults > "$work/t-up.log" 2>&1) || { cat "$work/t-up.log"; fail "3.0.0 update test: the update fails"; }
grep -q 'Migrations run: 4.0.0' "$work/t-up.log" && grep -q "\"_version\": \"$here\"" "$t/.afe-answers.json" ||
  { cat "$work/t-up.log"; fail "3.0.0 update test: the 4.0.0 migration does not run, or the new version is not recorded"; }
warnings="Warning: .claude/rules/docs.md has a local edit, which the update replaces with the template version $here; the old content is in Git.
Warning: .claude/harness.conf sets FWC_INSTALL, FWC_CLASSIFIER, which 4.0.0 no longer reads: delete them; the fail-without-change driver installs with SETUP.
Warning: .claude/hooks/project/stop/10-own.sh no longer runs: since 4.0.0 the Stop dispatcher does not run .claude/hooks/project/stop/, so register it under hooks.Stop in .claude/settings.project.json."
[ "$(grep '^Warning:' "$work/t-up.log")" = "$warnings" ] ||
  { cat "$work/t-up.log"; fail "3.0.0 update test: the warnings are not the local edit and the two steps by hand of 4.0.0"; }
(cd "$t" && scripts/check-template.sh > "$work/t-ct.log" 2>&1) || { cat "$work/t-ct.log"; fail "3.0.0 update test: the template check fails after the update"; }

(cd "$tc" && cli update --defaults > "$work/tc-up.log" 2>&1) || { cat "$work/tc-up.log"; fail "3.0.0 update test: the update of the project without leftovers fails"; }
! grep -q '^Warning:' "$work/tc-up.log" && (cd "$tc" && scripts/check-template.sh > "$work/tc-ct.log" 2>&1) ||
  { cat "$work/tc-up.log" "$work/tc-ct.log"; fail "3.0.0 update test: a project without 3.x leftovers gets a warning, or fails the template check"; }

# Interrupted: a migration after 4.0.0's fails once. The version stays 3.0.0; the second run runs
# the migrations again, reports the steps by hand again, and ends where the update without a
# failure ended.
failing_pkg "$work/p4f" "$here" "$work/fail-once-4" && touch "$work/fail-once-4"
(cd "$ti" && node "$work/p4f/bin/create-afe-project.js" update --defaults > "$work/ti1.log" 2>&1) &&
  fail "3.0.0 update test: the update with a failing migration succeeds"
grep -q '"_version": "3.0.0"' "$ti/.afe-answers.json" && grep -q 'injected failure' "$work/ti1.log" &&
  grep -q 'run the same update again with --allow-dirty' "$work/ti1.log" ||
  { cat "$work/ti1.log"; fail "3.0.0 update test: a failed migration records the new version, or the message does not say why and how to resume"; }
(cd "$ti" && node "$work/p4f/bin/create-afe-project.js" update --defaults --allow-dirty > "$work/ti2.log" 2>&1) ||
  { cat "$work/ti2.log"; fail "3.0.0 update test: the second run after a failed migration fails"; }
grep -q 'Migrations run: 4.0.0' "$work/ti2.log" && [ "$(grep -c '^Warning: .claude/h' "$work/ti2.log")" = 2 ] &&
  diff -r -x .git "$t" "$ti" > "$work/ti.diff" ||
  { cat "$work/ti2.log" "$work/ti.diff"; fail "3.0.0 update test: the second run does not run the migrations again, or ends elsewhere than an update without a failure"; }

# Once updated, the same update again changes nothing.
gitc "$t" add -A && gitc "$t" commit -q -m update
(cd "$t" && cli update --defaults > "$work/t-again.log" 2>&1) && [ -z "$(git -C "$t" status --porcelain)" ] ||
  { cat "$work/t-again.log"; git -C "$t" status --short | head; fail "3.0.0 update test: a second update changes the project"; }
