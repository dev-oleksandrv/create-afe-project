# The protect hook: tokens, targets behind cd and git -C, path folding, worktrees, other
# repositories. Needs $a from 10-variant-a.sh and hook from 60-hooks-guard.sh; sets $ghp.
# A known token format in written content or a command asks; the tokens are assembled here, so
# this file holds none.
aws="AKIA""IOSFODNN7EXAMPLE" ghp="ghp_""$(printf 'a%.0s' $(seq 1 36))" pk="-----BEGIN ""RSA PRIVATE KEY-----"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = \"'"$aws"'\""}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/src/x.js","old_string":"a","new_string":"token: '"$ghp"'"}}'
hook ask '{"tool_name":"MultiEdit","tool_input":{"file_path":"'"$a"'/k.pem","edits":[{"old_string":"a","new_string":"'"$pk"'"}]}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo '"$ghp"' > .token"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = os.environ[\"AWS_ACCESS_KEY_ID\"]"}}'
for c in "npm run build" "gh api repos/o/r/pulls" "docker build ." "git push origin main"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# A target behind `cd DIR` or `git -C DIR`, and a file an interpreter's heredoc names, resolve
# against that directory; the text of another heredoc is not read as commands.
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd docs && cat > contributing.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cd docs && echo x >> plans/x.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git -C docs checkout -- testing-rules.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd docs && python3 - <<EOF\np = \"contributing.md\"\nopen(p, \"w\").write(\"x\")\nEOF"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cat > /tmp/notes.txt <<EOF\nrm AGENTS.md\nEOF"}}'
# What the resolution must not loosen: a non-literal cd, a redirect on git -C, a shell's heredoc,
# and forms that look like a heredoc.
hook ask '{"tool_name":"Bash","tool_input":{"command":"cd \"$REPO\" && echo x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git -C /tmp log > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"bash <<EOF\necho SECRET=1 > .env\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"grep x <<< foo\necho x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cat <<EOF | bash\necho x > AGENTS.md\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"source /dev/stdin <<EOF\necho x > AGENTS.md\nEOF"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo $((1<<n))\necho x > AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"see <<EOF\"\necho x > AGENTS.md"}}'
# A ".." or "." in the part of the path that does not exist yet is folded before the match; a ".."
# left over climbs from the nearest existing directory, so the path may leave the repository.
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/docs/new/../README.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/./sub/../../docs/contributing.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > newdir/../AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/new/../contributing.md"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a/AGENTS.md"}}'
# A sibling worktree of the project is guarded by its own protected paths, although
# CLAUDE_PROJECT_DIR names the main checkout; the hook runs outside both. The sibling lists paths
# that the main checkout does not, so a hook that read the main checkout's lists, or resolved a
# relative Bash target against anything but the input's cwd, would allow them.
sib="$work/a-sibling"
gitc "$a" worktree add -q -b sibling "$sib"
printf 'approval sibling-only.txt\napproval gen/*\n' >> "$sib/.claude/path-classes"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/contributing.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/AGENTS.md"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/plans/x.md"}}' "$work"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/sibling-only.txt"}}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/sibling-only.txt"}}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > sibling-only.txt"},"cwd":"'"$sib"'"}' "$work"
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > docs/contributing.md"},"cwd":"/nonexistent"}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x '"$sib"'/docs/testing-rules.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/gen/new/x.txt"}}' "$work"
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/gen/new/../../../out.txt"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a-sibling/docs/contributing.md"}}' "$work"
git -C "$a" worktree remove --force "$sib" && gitc "$a" branch -q -D sibling
# A worktree inside the main checkout's directory is judged by its own repository too.
gitc "$a" worktree add -q -b inner "$a/.claude/worktrees/inner"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/.claude/worktrees/inner/docs/contributing.md"}}' "$work"
git -C "$a" worktree remove --force "$a/.claude/worktrees/inner" && gitc "$a" branch -q -D inner
# A nested repository without .template/owned.txt inside the project keeps the project's paths.
git init -q "$a/vendor/lib" && echo 'approval vendor/*' >> "$a/.claude/path-classes"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/vendor/lib/a.c"}}' "$work"
rm -rf "$a/vendor" && gitc "$a" checkout -q -- .claude/path-classes
# The session's project is guarded before its first commit, when it is not a git repository.
cp -R "$a" "$work/nogit" && rm -rf "$work/nogit/.git"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/nogit/docs/contributing.md"}}' "$work" "$work/nogit"
# Another repository without .template/owned.txt, and a path outside any repository and outside
# the session's project, are not guarded.
git init -q "$work/other" && mkdir -p "$work/other/docs" "$work/loose"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/other/docs/README.md"}}' "$work"
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$work"'/loose/AGENTS.md"}}' "$work"
