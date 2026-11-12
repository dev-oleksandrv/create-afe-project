# The 2.0.1 harness migration of Copier projects, .harness/ back to .claude/. Needs pkg and $sample
# from 90-update.sh.
# The 2.0.1 migration: a Copier project at upstream 0.7.0 or later keeps its harness settings and
# path classes in .harness/; the update moves them back to .claude/, with the paths in their
# lines renamed, instead of seeding the defaults next to them.
p201="$work/p201"
pkg "$p201" 2.0.1
# harness <dir>: the project's own .harness/ files, as upstream 0.7.0 moved them out of .claude/.
harness() {
  mkdir -p "$1/.harness" &&
    sed 's/^CHECK_FAST=.*/CHECK_FAST=false/' "$root/template/.claude/harness.conf" > "$1/.harness/harness.conf" &&
    { sed 's#[.]claude/harness[.]conf#.harness/harness.conf#g; s#[.]claude/path-classes#.harness/path-classes#g' "$root/template/.claude/path-classes"; echo 'gate custom/*'; } > "$1/.harness/path-classes"
}
# moved <dir> <log>: the custom values are in .claude/, custom/x is class gate, and .harness/ is gone.
moved() {
  grep -qx 'CHECK_FAST=false' "$1/.claude/harness.conf" && grep -qx 'gate custom/\*' "$1/.claude/path-classes" &&
    grep -qx 'gate .claude/harness.conf' "$1/.claude/path-classes" && ! grep -q '[.]harness/' "$1/.claude/path-classes" &&
    [ ! -e "$1/.harness" ] && ! grep -q 'Created missing seeded files:.*\.claude/' "$2" &&
    [ "$(cd "$1" && . scripts/lib/classes.sh && class_of custom/x HEAD)" = gate ]
}
cv="$work/cv"
node "$p201/bin/create-afe-project.js" "$cv" "${sample[@]}" > /dev/null 2>&1 || fail "harness migration test: create fails"
rm "$cv/.afe-answers.json" "$cv/.claude/harness.conf" "$cv/.claude/path-classes" && harness "$cv"
# A project document of a 0.7.0 project, such as its map, names the .harness/ paths; an update
# never rewrites it.
mkdir -p "$cv/docs" && printf '# Notes\n\nHarness settings: `.harness/harness.conf`.\n' > "$cv/docs/notes.md"
printf '_commit: v0.7.0\n_src_path: https://github.com/xandronak/agent-docs-template\ndocs_language: German\necosystems:\n- node\n- python\ngithub_repo: example/sample\nproject_description: A sample project.\nproject_name: sample\n' > "$cv/.copier-answers.yml"
gitc "$cv" add -A && gitc "$cv" commit -q -m copier
(cd "$cv" && node "$p201/bin/create-afe-project.js" update --defaults > "$work/cv.log" 2>&1) || { cat "$work/cv.log"; fail "harness migration test: the Copier update fails"; }
moved "$cv" "$work/cv.log" ||
  { cat "$work/cv.log"; fail "harness migration test: a Copier 0.7.0 project's .harness/ files are not moved to .claude/"; }
grep -q 'Warning: replace .harness/ with .claude/ in docs/notes.md by hand' "$work/cv.log" ||
  { cat "$work/cv.log"; fail "harness migration test: a file that still names .harness/ is not reported"; }
grep -q 'docs_language was German.*English.*[.]claude/rules/docs[.]md' "$work/cv.log" && grep -q 'not carried over.*docs_language.*ecosystems' "$work/cv.log" &&
  ! grep -q 'docs_language\|ecosystems' "$cv/.afe-answers.json" ||
  { cat "$work/cv.log" "$cv/.afe-answers.json"; fail "harness migration test: the dropped docs_language and ecosystems answers are not reported"; }
# A project that converted with 2.0.0 got the default .claude/ files next to the orphaned
# .harness/ ones: a default is replaced, a file the project changed is kept, and the report says
# to merge by hand.
ov="$work/ov"
pkg "$work/p200" 2.0.0
node "$work/p200/bin/create-afe-project.js" "$ov" "${sample[@]}" > /dev/null 2>&1 || fail "harness migration test: create at 2.0.0 fails"
harness "$ov" && gitc "$ov" add -A && gitc "$ov" commit -q -m orphaned
(cd "$ov" && node "$p201/bin/create-afe-project.js" update --defaults > "$work/ov.log" 2>&1) || { cat "$work/ov.log"; fail "harness migration test: the update from 2.0.0 fails"; }
moved "$ov" "$work/ov.log" && ! grep -q 'Warning:' "$work/ov.log" ||
  { cat "$work/ov.log"; fail "harness migration test: the orphaned .harness/ files of a 2.0.0 project are not moved to .claude/"; }
git -C "$ov" reset -q --hard && git -C "$ov" clean -q -f -d && echo 'gate own/*' >> "$ov/.claude/path-classes" && gitc "$ov" add -A && gitc "$ov" commit -q -m edited
(cd "$ov" && node "$p201/bin/create-afe-project.js" update --defaults > "$work/ov2.log" 2>&1) || { cat "$work/ov2.log"; fail "harness migration test: the second update from 2.0.0 fails"; }
grep -qx 'CHECK_FAST=false' "$ov/.claude/harness.conf" && grep -qx 'gate own/\*' "$ov/.claude/path-classes" &&
  [ -f "$ov/.harness/path-classes" ] && [ ! -e "$ov/.harness/harness.conf" ] &&
  grep -q 'merge .harness/path-classes into .claude/path-classes by hand' "$work/ov2.log" ||
  { cat "$work/ov2.log"; fail "harness migration test: a changed .claude/path-classes is replaced, or the merge by hand is not reported"; }
