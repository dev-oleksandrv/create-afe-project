# The guard hook: tokens, shell commands, path folding, worktrees, other repositories. Needs $a
# from 10-variant-a.sh and hook from 60-hooks-guard.sh; sets $ghp.
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
# A shell command that writes a path passes, AGENTS.md included (the known limit).
for c in "cd docs && cat > contributing.md" "echo x > AGENTS.md" "git -C docs checkout -- testing-rules.md" "cat <<EOF | bash\necho x > AGENTS.md\nEOF"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# A ".." or "." in the part of the path that does not exist yet is folded before the match; a ".."
# left over climbs from the nearest existing directory, so the path may leave the repository.
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/docs/new/../../AGENTS.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/newdir/./sub/../../AGENTS.md"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../AGENTS.md"}}'
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a/AGENTS.md"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/AGENTS.md"}}'
# A sibling worktree of the project is judged by its own root, although CLAUDE_PROJECT_DIR names
# the main checkout; the hook runs outside both. Its AGENTS.md is no path of the main checkout, so
# a hook that judged it by the main checkout would allow it.
sib="$work/a-sibling"
gitc "$a" worktree add -q -b sibling "$sib"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$sib"'/AGENTS.md"}}' "$work"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"AGENTS.md"},"cwd":"'"$sib"'"}' "$work"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$sib"'/docs/contributing.md"}}' "$work"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/newdir/../../a-sibling/AGENTS.md"}}' "$work"
git -C "$a" worktree remove --force "$sib" && gitc "$a" branch -q -D sibling
# A worktree inside the main checkout's directory is judged by its own repository too.
gitc "$a" worktree add -q -b inner "$a/.claude/worktrees/inner"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/.claude/worktrees/inner/AGENTS.md"}}' "$work"
git -C "$a" worktree remove --force "$a/.claude/worktrees/inner" && gitc "$a" branch -q -D inner
# The session's project is guarded before its first commit, when it is not a git repository.
cp -R "$a" "$work/nogit" && rm -rf "$work/nogit/.git"
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/nogit/AGENTS.md"}}' "$work" "$work/nogit"
# Another repository without .template/owned.txt, and a path outside any repository and outside
# the session's project, are not guarded.
git init -q "$work/other" && mkdir -p "$work/loose"
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$work"'/other/AGENTS.md"}}' "$work"
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$work"'/loose/AGENTS.md"}}' "$work"
