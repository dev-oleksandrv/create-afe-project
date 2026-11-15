# update keeps project content. Needs lib.sh only; defines pkg, failing_pkg, $tpl, and $sample for
# the later update files.
echo "== update keeps project content"
# pkg <dir> <version>: a copy of this package at another version, sharing node_modules.
pkg() {
  mkdir -p "$1" && cp -R bin src template package.json "$1/" && ln -s "$root/node_modules" "$1/node_modules"
  node -e 'const f=process.argv[1]+"/package.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.version=process.argv[2];fs.writeFileSync(f,JSON.stringify(p))' "$1" "$2"
}
# failing_pkg <dir> <version> <marker>: pkg with one more migration of <version>, the last one,
# that fails while the file <marker> exists, and removes it: an update interrupted once.
failing_pkg() {
  pkg "$1" "$2" &&
    printf "MIGRATIONS.push({ version: '%s', after: 'if [ -e \"%s\" ]; then rm \"%s\"; echo injected failure >&2; exit 1; fi' });\n" \
      "$2" "$3" "$3" >> "$1/src/config.js"
}
sample=(--defaults --quiet --data project_name=sample --data 'project_description=A sample project.' --data github_repo=example/sample)
tpl="$work/tpl"
pkg "$tpl" 0.0.1
u="$work/u"
node "$tpl/bin/create-afe-project.js" "$u" "${sample[@]}" > "$work/u.log" 2>&1 || { cat "$work/u.log"; fail "update test: create fails"; }
git -C "$u" init -q -b main
awk '{print} /<!-- project:start -->/ {print "Project line one."; print "Project line two."}' "$u/AGENTS.md" > "$work/ag" && mv "$work/ag" "$u/AGENTS.md"
echo "Project note." >> "$u/README.md"
mkdir -p "$u/scripts/checks.d" && printf '#!/usr/bin/env bash\necho project check\n' > "$u/scripts/checks.d/10-sample.sh" && chmod +x "$u/scripts/checks.d/10-sample.sh"
rm "$u/.claude/harness.conf"
gitc "$u" add -A && gitc "$u" commit -q -m init
printf '\nA line added by the next template version.\n' >> "$tpl/template/.claude/skills/review/rubric.md.jinja"
sed -i.bak '/^scripts\/protect-branch.sh$/d' "$tpl/template/.template/owned.txt.jinja" && rm "$tpl/template/scripts/protect-branch.sh" "$tpl/template/.template/owned.txt.jinja.bak"
node -e 'const f=process.argv[1],fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.version="0.0.2";fs.writeFileSync(f,JSON.stringify(p))' "$tpl/package.json"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/up.log" 2>&1) || { cat "$work/up.log"; fail "update test: update fails"; }
! grep -q '^Warning:' "$work/up.log" || { cat "$work/up.log"; fail "update test: a project without local edits of template-owned files gets a warning"; }
grep -q 'Project line two.' "$u/AGENTS.md" || fail "update test: the project block was lost"
grep -q 'Project note.' "$u/README.md" || fail "update test: the seeded README was overwritten"
[ -f "$u/.claude/harness.conf" ] || fail "update test: a missing seeded file was not created"
[ -x "$u/scripts/checks.d/10-sample.sh" ] || fail "update test: the project check was lost"
grep -q 'added by the next template version' "$u/.claude/skills/review/rubric.md" || fail "update test: the template change did not arrive"
[ ! -e "$u/scripts/protect-branch.sh" ] || fail "update test: a file the template no longer owns was kept"
grep -q '"_version": "0.0.2"' "$u/.afe-answers.json" || fail "update test: the answers file does not record 0.0.2"
(cd "$u" && scripts/check-template.sh > "$work/ut.log" 2>&1) || { cat "$work/ut.log"; fail "update test: template check fails after the update"; }
gitc "$u" add -A && gitc "$u" commit -q -m update
echo "A line of a local edit." >> "$u/.claude/skills/update-template/SKILL.md" && echo "dirty" > "$u/scratch.txt"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > /dev/null 2>&1) &&
  fail "update test: update runs on a working tree with uncommitted changes"
rm "$u/scratch.txt" && gitc "$u" commit -q -am "edit a template-owned file"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/up2.log" 2>&1) || { cat "$work/up2.log"; fail "update test: second update fails"; }
! grep -q 'A line of a local edit.' "$u/.claude/skills/update-template/SKILL.md" ||
  { cat "$work/up2.log"; fail "update test: a local edit of a template-owned file is not replaced"; }
# With --defaults the local edit is a warning, printed before the update replaces it; the lines of
# the project block of AGENTS.md are none.
[ "$(grep -c '^Warning:' "$work/up2.log")" = 1 ] && head -n 1 "$work/up2.log" |
  grep -q -x 'Warning: .claude/skills/update-template/SKILL.md has a local edit, which the update replaces with the template version 0.0.2; the old content is in Git.' ||
  { cat "$work/up2.log"; fail "update test: the replaced local edit is not the one warning, before the report"; }
pkg "$work/new" 0.0.3
(cd "$u" && node "$work/new/bin/create-afe-project.js" update --defaults --allow-dirty > /dev/null 2>&1) || fail "update test: update to a newer version fails"
(cd "$u" && node "$tpl/bin/create-afe-project.js" update --defaults --allow-dirty > "$work/down.log" 2>&1) &&
  fail "update test: an older package downgrades the project"
# A project with only a Copier answers file is no project of this package: it updates with
# create-afe-project 3 first.
v="$work/v"
node "$tpl/bin/create-afe-project.js" "$v" "${sample[@]}" --no-git > /dev/null 2>&1 || fail "update test: create fails"
rm "$v/.afe-answers.json" && printf '_commit: v0.6.0\nproject_name: sample\n' > "$v/.copier-answers.yml"
(cd "$v" && node "$tpl/bin/create-afe-project.js" update --defaults > "$work/v.log" 2>&1) &&
  fail "update test: a project with only a Copier answers file is updated"
grep -q 'has no answers file' "$work/v.log" || { cat "$work/v.log"; fail "update test: the update of a Copier project fails for another reason"; }
# Without .template/owned.sha256 the update cannot tell local edits, says so, and goes on.
w="$work/w"
cli "$w" "${sample[@]}" > /dev/null 2>&1 || fail "update test: create fails"
gitc "$w" rm -q .template/owned.sha256 && gitc "$w" commit -q -m "no manifest"
(cd "$w" && cli update --defaults > "$work/w.log" 2>&1) && [ -f "$w/.template/owned.sha256" ] &&
  grep -q -x 'Warning: .template/owned.sha256 is missing, so the update cannot tell the local edits of template-owned files, and replaces them all.' "$work/w.log" ||
  { cat "$work/w.log"; fail "update test: an update without .template/owned.sha256 fails, or does not warn that it cannot tell local edits"; }
