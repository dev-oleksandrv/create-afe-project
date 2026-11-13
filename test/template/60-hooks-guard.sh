# The guard hook: AGENTS.md, irreversible commands, repository settings, DOCS_GUARD=off. Needs $a
# from 10-variant-a.sh; defines hook, which the later hook files use.
echo "== hooks on variant A"
hook() { # expected decision (ask|deny|allow), JSON input, directory the hook runs in, CLAUDE_PROJECT_DIR (both default: variant A)
  local out
  out=$(cd "${3:-$a}" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="${4:-$a}" "$a/.claude/hooks/guard.sh" 2>&1)
  case "$1:$out" in
    ask:*'"permissionDecision":"ask"'*|deny:*'"permissionDecision":"deny"'*|allow:) ;;
    *) fail "guard hook: expected $1 for $2, got '${out:0:120}'" ;;
  esac
}
# An Edit, Write, or MultiEdit of AGENTS.md at the root asks; no other path does: not the
# documentation map, a template-owned file, a generated file, the path classes, an AGENTS.md
# below the root, or a decision record that exists on main.
for t in Edit Write MultiEdit; do
  hook ask '{"tool_name":"'"$t"'","tool_input":{"file_path":"'"$a"'/AGENTS.md"}}'
done
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/../AGENTS.md"}}'
hook ask '{"tool_name":"Edit","tool_input":{"file_path":"AGENTS.md"},"cwd":"'"$a"'"}'
for p in docs/README.md docs/contributing.md scripts/check.sh scripts/lib/stamp.sh .claude/hooks/guard.sh .template/owned.txt \
  .template/owned.sha256 .afe-answers.json .claude/settings.json .claude/settings.template.json .claude/settings.project.json \
  .claude/path-classes .mcp.json .env docs/decisions/README.md docs/AGENTS.md src/AGENTS.md scripts/checks.d/20-x.sh \
  .github/workflows/ci.yml package.json src/auth/login.py .claude/harness.conf; do
  hook allow '{"tool_name":"Write","tool_input":{"file_path":"'"$a/$p"'"}}'
done
start=$(git -C "$a" rev-parse HEAD)
printf -- '---\nstatus: accepted\n---\n\n# Accepted\n' > "$a/docs/decisions/0001-on-main.md"
gitc "$a" add -A && gitc "$a" commit -q -m adr
hook allow '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/decisions/0001-on-main.md"}}'
git -C "$a" reset -q --hard "$start"
# A shell command is not checked for the paths it writes (the known limit of the hook header), so
# these pass; scripts/check-template.sh catches a changed template part.
for c in "echo x > AGENTS.md" "scripts/check-template.sh --write" "rm .template/owned.txt" "cp /tmp/x docs/contributing.md" \
  "scripts/check.sh 2>&1 | tee /tmp/check.log" "echo approval x >> .claude/path-classes"; do
  hook allow '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
# The irreversible commands the hook names ask, and not an ordinary push.
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
# DOCS_GUARD=off passes everything: AGENTS.md, an irreversible command, a secret format.
aws="AKIA""IOSFODNN7EXAMPLE"
for in_json in '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/AGENTS.md"}}' '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 3"}}' \
  '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/x.py","content":"'"$aws"'"}}'; do
  out=$(cd "$a" && printf '%s' "$in_json" | DOCS_GUARD=off CLAUDE_PROJECT_DIR="$a" .claude/hooks/guard.sh 2>&1) && [ -z "$out" ] ||
    fail "guard hook: DOCS_GUARD=off does not pass $in_json: '${out:0:120}'"
done
