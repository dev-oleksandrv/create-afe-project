# The guard hook: known token formats, what it leaves to the permission rules, DOCS_GUARD=off.
# Needs $a from 10-variant-a.sh; defines hook and sets $ghp, which the later hook files use.
echo "== hooks on variant A"
hook() { # expected decision (ask|deny|allow), JSON input, directory the hook runs in, CLAUDE_PROJECT_DIR (both default: variant A)
  local out
  out=$(cd "${3:-$a}" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="${4:-$a}" "$a/.claude/hooks/guard.sh" 2>&1)
  case "$1:$out" in
    ask:*'"permissionDecision":"ask"'*|deny:*'"permissionDecision":"deny"'*|allow:) ;;
    *) fail "guard hook: expected $1 for $2, got '${out:0:120}'" ;;
  esac
}
# A known token format in written content or a command asks; the tokens are assembled here, so
# this file holds none.
aws="AKIA""IOSFODNN7EXAMPLE" ghp="ghp_""$(printf 'a%.0s' $(seq 1 36))" pk="-----BEGIN ""RSA PRIVATE KEY-----"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = \"'"$aws"'\""}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/src/x.js","old_string":"a","new_string":"token: '"$ghp"'"}}'
hook ask '{"tool_name":"MultiEdit","tool_input":{"file_path":"'"$a"'/k.pem","edits":[{"old_string":"a","new_string":"'"$pk"'"}]}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo '"$ghp"' > .token"}}'
hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/config.py","content":"KEY = os.environ[\"AWS_ACCESS_KEY_ID\"]"}}'
# The hook does not judge paths or irreversible commands: scripts/check-template.sh catches a
# changed template part of AGENTS.md, and the commands are permission rules of the settings.
for t in Edit Write MultiEdit; do
  hook allow '{"tool_name":"'"$t"'","tool_input":{"file_path":"'"$a"'/AGENTS.md"}}'
done
for c in "gh pr merge 3 --merge" "npm publish" "gh api -X DELETE repos/o/r/git/refs/heads/x" "scripts/protect-branch.sh" "git push origin v1.2.0"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# The settings ask before the irreversible commands: a push of tags, a merge, a release, a change
# of repository settings, a deletion or a GraphQL call through gh api, and publishing.
for r in "Bash(git push * --tags*)" "Bash(git push * refs/tags/*)" "Bash(gh pr merge *)" "Bash(gh release create *)" "Bash(gh repo edit *)" \
  "Bash(gh workflow run *)" "Bash(gh api *DELETE*)" "Bash(gh api *graphql*)" "Bash(gh api */rulesets*)" "Bash(gh api */protection*)" \
  "Bash(scripts/protect-branch.sh *)" "Bash(npm publish *)" "Bash(cargo publish *)" "Bash(twine upload *)" "Bash(docker push *)"; do
  (cd "$a" && "$work/sj" "s.permissions.ask.includes(process.argv[1])" "$r") || fail "settings: no ask rule $r"
done
# DOCS_GUARD=off passes a secret format too.
out=$(cd "$a" && printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/x.py","content":"'"$aws"'"}}' | DOCS_GUARD=off CLAUDE_PROJECT_DIR="$a" .claude/hooks/guard.sh 2>&1) &&
  [ -z "$out" ] || fail "guard hook: DOCS_GUARD=off does not pass a secret format: '${out:0:120}'"
