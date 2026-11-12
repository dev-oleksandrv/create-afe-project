# The protect hook: class approval, irreversible commands, repository settings. Needs $a from
# 10-variant-a.sh; defines hook, which the later hook files use.
echo "== hooks on variant A"
hook() { # expected decision (ask|deny|allow), JSON input, directory the hook runs in, CLAUDE_PROJECT_DIR (both default: variant A)
  local out
  out=$(cd "${3:-$a}" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="${4:-$a}" "$a/.claude/hooks/protect-docs.sh" 2>&1)
  case "$1:$out" in
    ask:*'"permissionDecision":"ask"'*|deny:*'"permissionDecision":"deny"'*|allow:) ;;
    *) fail "protect hook: expected $1 for $2, got '${out:0:120}'" ;;
  esac
}
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/contributing.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/../AGENTS.md"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"scripts/check-template.sh --write"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo x > \"docs/documentation-rules.md\""}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"rm .template/owned.txt"}}'
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/plans/x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"cp docs/decisions/adr-template.md docs/decisions/0001-x.md"}}'
hook allow '{"tool_name":"Bash","tool_input":{"command":"scripts/check.sh 2>&1 | tee /tmp/check.log"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/contributing.md"}}'
# Class approval asks; gate, high, normal, and low paths need no prompt; so do the irreversible
# commands the hook names, and not an ordinary push.
for p in .claude/path-classes .claude/settings.project.json .claude/settings.json .mcp.json .env .claude/settings.template.json; do
  hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a/$p"'"}}'
done
for p in scripts/checks.d/20-x.sh .github/workflows/ci.yml package.json src/auth/login.py .claude/harness.conf; do
  hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a/$p"'"}}'
done
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo KEY=x >> .env.local"}}'
hook ask '{"tool_name":"Bash","tool_input":{"command":"echo approval x >> .claude/path-classes"}}'
for c in "git push --force origin main" "git push -uf origin feature" "git push origin +feature" "git push origin --delete feature" \
  "git push origin v1.2.0" "git push origin refs/tags/x" "gh pr merge 3 --merge" "scripts/check.sh && gh release create v1.0.0" "gh repo delete example/sample --yes" \
  "git -C . push --force origin feature" "gh workflow run release.yml" "gh api -X DELETE repos/o/r/git/refs/heads/x" \
  "npm publish" "pnpm publish --access public" "cargo publish" "docker push example/app:1" "twine upload dist/*"; do
  hook ask '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# A change of repository settings: scripts/protect-branch.sh without --dry-run in any path form,
# and a gh api write, explicit or implied by -f, -F, or --input, on the repository, its rulesets,
# or a branch protection; gh repo edit, rename, and archive; a GraphQL mutation, and a gh api
# graphql query the hook cannot read (a file, --input, a command substitution, several lines);
# a full URL as the endpoint. Reads, a dry run,
# GraphQL queries, and the replies and reads of the create-pr skill pass.
for c in "scripts/protect-branch.sh" "./scripts/protect-branch.sh --repo o/r" "bash scripts/protect-branch.sh --require-base" \
  "$a/scripts/protect-branch.sh" "cd scripts && ./protect-branch.sh" "gh api --method PATCH repos/o/r" "gh api -X PUT repos/o/r/rulesets/1" \
  "gh api --method=POST /repos/o/r/rulesets --input -" "gh api -XPUT repos/o/r/branches/main/protection --input p.json" \
  "gh api -X patch 'repos/{owner}/{repo}'" "gh api repos/o/r/rulesets -f name=x" "gh api repos/o/r -F allow_squash_merge=false" \
  "gh api repos/o/r --input settings.json" "gh api --field=enforcement=active repos/o/r/rulesets/2" \
  "gh api --method PUT -H 'Accept: application/vnd.github+json' /repos/o/r/branches/main/protection --input p.json" \
  "scripts/protect-branch.sh # --dry-run" "bash -o pipefail scripts/protect-branch.sh" "bash --rcfile x.rc ./scripts/protect-branch.sh" "gh api -XDELETE repos/o/r/x" "gh api --method=delete repos/o/r/x" "gh api -H 'Accept: x' -X DELETE repos/o/r/x" \
  "gh repo edit --visibility public" "gh repo edit o/r --enable-squash-merge" "gh repo rename sample2" "gh repo archive o/r --yes" \
  "gh api graphql -f query='mutation { addStar(input: {}) { clientMutationId } }'" "gh api graphql -F query=@m.graphql" \
  "gh api graphql --raw-field 'query=mutation{deleteRef}'" "gh api /graphql --field=query='mutation X { y }'" "gh api graphql --input q.json" \
  "gh api graphql -f query=\$(cat m.graphql)" "gh api graphql -f query='\n  mutation {\n    x\n  }'" "gh api graphql -f 'query=\nmutation { x }'" \
  "gh api graphql -f query='query { a }\nmutation M { x }'" "gh api https://api.github.com/graphql -f query='mutation { x }'" \
  "gh api https://ghe.example.com/api/v3/repos/o/r -X PATCH -f private=true" "gh api graphql -fquery='mutation { x }'" \
  "gh api graphql -Fquery=@m.graphql" "gh api graphql -F query=@-" "gh api graphql -f query=\`cat m.graphql\`"; do
  hook ask '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
for c in "scripts/protect-branch.sh --dry-run" "./scripts/protect-branch.sh --repo o/r --dry-run" \
  "gh api repos/{owner}/{repo}/pulls/3/comments/7/replies -f body=Fixed" "gh api repos/{owner}/{repo}/issues/3/comments" \
  "gh api repos/{owner}/{repo}/pulls/3/comments" "gh api repos/o/r/rulesets" "gh api repos/o/r --jq .default_branch" \
  "gh api -X GET repos/o/r/rulesets -f includes_parents=true" "gh api --method POST repos/o/r/issues/3/comments -f body=x" \
  "gh api -f 'body=see repos/o/r' repos/{owner}/{repo}/pulls/3/comments/7/replies" "gh repo view" "gh repo view o/r --json name" \
  "gh repo clone o/r" "gh api graphql -f query='query { viewer { login } }'" "gh api graphql -F query='{ viewer { mutationsCount: login } }'"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# An approval line of .claude/path-classes asks even where a built-in rule would allow the edit.
printf 'approval docs/decisions/*\n' >> "$a/.claude/path-classes"
hook ask '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/docs/decisions/0001-new.md"}}'
gitc "$a" checkout -q -- .claude/path-classes
