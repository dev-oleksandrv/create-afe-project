# The skills of the generated project: afe-init and update-template always, review-code only
# with the code_review module; each opens its pull request itself. Needs $a from 10-variant-a.sh
# and $b from 13-variant-b.sh.
echo "== skills: afe-init, update-template, and review-code with its module"
[ "$(cd "$a/.claude/skills" && ls | tr '\n' ' ')" = 'afe-init update-template ' ] || fail "variant A: the skills are '$(cd "$a/.claude/skills" && ls | tr '\n' ' ')'"
[ "$(cd "$b/.claude/skills" && ls | tr '\n' ' ')" = 'afe-init review-code update-template ' ] || fail "variant B: the skills are '$(cd "$b/.claude/skills" && ls | tr '\n' ' ')'"
for s in afe-init update-template; do
  f="$a/.claude/skills/$s/SKILL.md"
  [ "$(sed -n 1p "$f")" = '---' ] && grep -q "^name: $s\$" "$f" && grep -q '^description: ' "$f" && grep -q '^allowed-tools: ' "$f" ||
    fail "$s: the front matter lacks name, description, or allowed-tools"
  # The skill may run the commands of the pull request it opens.
  grep -q '^allowed-tools: .*Bash(gh pr create:\*)' "$f" && grep -q '^allowed-tools: .*Bash(git commit:\*)' "$f" ||
    fail "$s: the allowed tools do not cover the commit and the pull request it opens"
done
grep -q '^disable-model-invocation: true$' "$a/.claude/skills/afe-init/SKILL.md" || fail "afe-init can be started by the model"
# The review in CI changes nothing and takes its rules from the base branch.
f="$b/.claude/skills/review-code/SKILL.md"
[ "$(grep '^allowed-tools: ' "$f")" = 'allowed-tools: Read, Grep, Glob, mcp__github_inline_comment__create_inline_comment' ] ||
  fail "review-code: the allowed tools are not read-only plus the inline comment tool"
grep -qF '<directory of the base branch' "$f" && grep -qF '<head commit of the pull request>' "$f" ||
  fail "review-code: the arguments do not name the base branch's rules and the head commit"
