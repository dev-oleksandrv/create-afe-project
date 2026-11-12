# Harness hooks in GitHub Actions run no code of the working tree; the review jobs disable them.
# Needs $a from 10-variant-a.sh, $b from 13-variant-b.sh, and $ghp from 65-hooks-guard-paths.sh.
# The review jobs check out the pull request's head; claude-code-action restores .claude/ from the
# base, but the scripts a base hook runs or sources stay at the head, next to the job's credentials.
# Every hook but the protect hook exits at once in GitHub Actions; the protect hook stays on there
# and runs no file of the working tree.
echo "== harness hooks in GitHub Actions run no code of the working tree"
while IFS= read -r f; do
  first=$(grep -v -E '^[[:space:]]*(#|$)' "$f" | head -n 1)
  [ "$first" = '[ -z "${GITHUB_ACTIONS:-}" ] || exit 0' ] || fail "$f: the first command is not the GitHub Actions guard"
done < <(find template/.claude/hooks -type f -name '*.sh' ! -name protect-docs.sh)
# A script of the project root, or one an interpreter runs by path, counts as a file it runs.
grep -v -E '^[[:space:]]*#' template/.claude/hooks/protect-docs.sh |
  grep -n -E 'GITHUB_ACTIONS|scripts/lib|(^|[;&|(]|then|do|else)[[:space:]]*(\.|source)[[:space:]]|"?\$\{?(root|project|cwd)\}?/[^"[:space:]]*\.(sh|mjs|cjs|js|py)|(^|[;&|(]|then|do|else)[[:space:]]*(bash|sh|node|python3?)[[:space:]]+[^-[:space:]]' &&
  fail "protect-docs.sh skips GitHub Actions, or runs or sources a file of the working tree, which a pull request supplies there"
# @secret moved into the protect hook: a caller that still asks json.mjs for it fails, not gets "".
printf '{}' | node "$a/scripts/lib/json.mjs" fields tool_name @secret > /dev/null 2>&1 &&
  fail "json.mjs fields: an unknown @ field prints an empty value instead of failing"
# Each script a hook runs or sources, and a project Stop hook, records that it ran.
mark="$work/head-code-ran"
for s in scripts/lib/json.mjs scripts/lib/git-base.sh scripts/lib/harness-conf.sh scripts/check-decisions.sh \
  scripts/check-template.sh scripts/check-docs.sh scripts/env.sh; do
  case "$s" in
    *.mjs) line="import { appendFileSync as markRan } from \"node:fs\"; markRan(\"$mark\", \"$s\\n\");" ;;
    *) line="echo $s >> \"$mark\"" ;;
  esac
  { head -n 1 "$a/$s"; printf '%s\n' "$line"; tail -n +2 "$a/$s"; } > "$work/planted" && cat "$work/planted" > "$a/$s"
done
mkdir -p "$a/.claude/hooks/project/stop" && printf '#!/bin/sh\necho project-stop >> "%s"\n' "$mark" > "$a/.claude/hooks/project/stop/10-mark.sh" &&
  chmod +x "$a/.claude/hooks/project/stop/10-mark.sh"
sed -i.bak "s#^CHECK_EDIT=.*#CHECK_EDIT=echo#; s#^CHECK_FAST=.*#CHECK_FAST=echo#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"
ci() { # hook, its input, the protect hook's decision (ask|deny; empty: none)
  rm -f "$mark"
  (cd "$a" && printf '%s' "$2" | GITHUB_ACTIONS=true CLAUDE_PROJECT_DIR="$a" ".claude/hooks/$1" > "$work/ci.log" 2>&1)
  local s=$?
  [ "$s" -eq 0 ] && [ ! -e "$mark" ] || { cat "$work/ci.log" "$mark" 2> /dev/null; fail "$1: exits $s or runs code of the working tree in GitHub Actions"; }
  if [ -n "${3:-}" ]; then
    grep -q "\"permissionDecision\":\"$3\"" "$work/ci.log" || { cat "$work/ci.log"; fail "$1: does not answer $3 in GitHub Actions for $2"; }
  elif [ "$1" = protect-docs.sh ] && [ -s "$work/ci.log" ]; then
    cat "$work/ci.log"; fail "$1: answers in GitHub Actions for $2"
  fi
}
# Every hook, a new one included, with the input of its event; the protect hook still asks.
edit='{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/README.md"},"cwd":"'"$a"'"}'
while IFS= read -r h; do
  case "$h" in
    session-start.sh) ci "$h" '{}' ;;
    post-edit-check.sh) ci "$h" "$edit" ;;
    protect-docs.sh)
      ci "$h" '{"tool_name":"Edit","tool_input":{"file_path":"'"$a"'/docs/contributing.md"},"cwd":"'"$a"'"}' ask
      ci "$h" '{"tool_name":"Bash","tool_input":{"command":"echo x > AGENTS.md"},"cwd":"'"$a"'"}' ask
      ci "$h" '{"tool_name":"Write","tool_input":{"file_path":"'"$a"'/src/x.js","content":"t = \"'"$ghp"'\""},"cwd":"'"$a"'"}' ask
      ci "$h" '{"tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"'"$a"'"}'
      ci "$h" "$edit" ;;
    *) ci "$h" '{"session_id":"ci"}' ;;
  esac
done < <(cd "$a/.claude/hooks" && find . -maxdepth 1 -type f -name '*.sh' | sed 's#^\./##' | sort)
# Outside GitHub Actions the planted code runs, so the test above proves something.
rm -f "$mark"
(cd "$a" && printf '%s' "$edit" | CLAUDE_PROJECT_DIR="$a" .claude/hooks/post-edit-check.sh > /dev/null 2>&1)
(cd "$a" && printf '{}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/session-start.sh > /dev/null 2>&1)
(cd "$a" && printf '{"session_id":"ci"}' | CLAUDE_PROJECT_DIR="$a" .claude/hooks/stop-run-project-hooks.sh > /dev/null 2>&1)
for s in scripts/lib/json.mjs scripts/lib/git-base.sh project-stop; do
  grep -qx "$s" "$mark" 2> /dev/null || fail "hooks: the planted $s does not run outside GitHub Actions, so the test above proves nothing"
done
gitc "$a" checkout -q -- . && rm -rf "$mark" "$a/.claude/hooks/project" "$(git -C "$a" rev-parse --absolute-git-dir)"/ralph-stops-*
for w in code-review; do
  awk '/^  review:$/ {f=1; next} /^  [a-z-]+:$/ {f=0} f' "$b/.github/workflows/$w.yml" | grep -v '^ *#' > "$work/$w-review.yml"
  grep -qF -- "--settings ''{\"disableAllHooks\": true}''" "$work/$w-review.yml" &&
    grep -qF -- '--disallowedTools "Edit,Write,MultiEdit,NotebookEdit,Bash"' "$work/$w-review.yml" &&
    ! grep -q -E 'scripts/|\.claude/|git (checkout|restore)' "$work/$w-review.yml" ||
    fail "$w: the review job runs or restores a file of the repository, or does not disable the hooks for Claude Code"
done
