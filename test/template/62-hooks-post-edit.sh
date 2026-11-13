# post-edit-check.sh: CHECK_EDIT after every edit, in any worktree. Needs $a from 10-variant-a.sh.
# The check after every edit: CHECK_EDIT runs on the changed file and reports a failure with exit 2.
pe() { (cd "$a" && printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"'"$1"'"}}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1); }
printf 'bad\n' > "$a/pe.txt" && printf 'ok\n' > "$a/pe-ok.txt" && cp "$a/pe.txt" "$work/outside.txt"
pe "$a/pe.txt" || fail "post-edit: runs although CHECK_EDIT is empty"
printf 'CHECK_EDIT=grep -q ok\n' >> "$a/.claude/harness.conf"
pe "$a/pe.txt"; [ $? -eq 2 ] && grep -q "CHECK_EDIT failed on pe.txt" "$work/pe.log" || { cat "$work/pe.log"; fail "post-edit: a failing CHECK_EDIT is not reported"; }
pe "$a/pe-ok.txt" || { cat "$work/pe.log"; fail "post-edit: a passing CHECK_EDIT is reported"; }
# CHECK_EDIT reads /dev/null, not the hook's spent input pipe: a command never sees a pipe on stdin.
printf 'CHECK_EDIT=test ! -p /dev/stdin && true\n' >> "$a/.claude/harness.conf"
pe "$a/pe.txt" || { cat "$work/pe.log"; fail "post-edit: CHECK_EDIT gets the hook's stdin, not /dev/null"; }
printf 'CHECK_EDIT=grep -q ok\n' >> "$a/.claude/harness.conf"
mkdir -p "$a/sub" && printf 'bad\n' > "$a/sub/pe.txt" && printf 'bad\n' > "$a/pe-rel.txt"
(cd "$a" && printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"pe-rel.txt"},"cwd":"'"$a"'/sub"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1)
[ $? -eq 0 ] || { cat "$work/pe.log"; fail "post-edit: a relative path missing in the input's cwd is taken from the project root"; }
(cd "$a" && printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"pe.txt"},"cwd":"'"$a"'/sub"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1)
[ $? -eq 2 ] && grep -q "CHECK_EDIT failed on sub/pe.txt" "$work/pe.log" || { cat "$work/pe.log"; fail "post-edit: a relative path is not resolved against the input's cwd"; }
for in_cwd in '' ',"cwd":""'; do
  (cd "$a" && printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"pe-rel.txt"}'"$in_cwd"'}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1)
  [ $? -eq 2 ] && grep -q "CHECK_EDIT failed on pe-rel.txt" "$work/pe.log" || { cat "$work/pe.log"; fail "post-edit: a relative path without a cwd ($in_cwd) is not resolved against the project root"; }
done
rm -rf "$a/sub" "$a/pe-rel.txt"
pe "$work/outside.txt" || fail "post-edit: checks a file outside the project"
printf 'CHECK_EDIT_GLOBS=src/*.py\n' >> "$a/.claude/harness.conf"
pe "$a/pe.txt" || fail "post-edit: checks a file that CHECK_EDIT_GLOBS leaves out"
gitc "$a" checkout -q -- .claude/harness.conf && rm -f "$a/pe.txt" "$a/pe-ok.txt"
# A file in a second worktree runs that worktree's CHECK_EDIT from its root, with the path relative
# to it, although the session's project is the main checkout and has no CHECK_EDIT.
pwt="$work/pe-wt"
gitc "$a" worktree add -q -b pewt "$pwt" && printf 'CHECK_EDIT=grep -q ok\n' >> "$pwt/.claude/harness.conf"
mkdir -p "$pwt/sub" && printf 'bad\n' > "$pwt/sub/pe.txt"
(cd "$a" && printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"'"$pwt"'/sub/pe.txt"},"cwd":"'"$a"'"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > "$work/pe.log" 2>&1)
[ $? -eq 2 ] && grep -q "CHECK_EDIT failed on sub/pe.txt" "$work/pe.log" || { cat "$work/pe.log"; fail "post-edit: a file in a second worktree is not checked by that worktree's CHECK_EDIT, relative to its root"; }
git -C "$a" worktree remove --force "$pwt" && gitc "$a" branch -q -D pewt
