# The guard hook denies a push to the default branch once the remote has it. Needs $a from
# 10-variant-a.sh, hook and $ghp from 60-hooks-guard.sh, and $work/r-none.md from 40-readiness.sh.
# A pushed feature branch must still be compared with main, not with its own upstream.
git init -q --bare "$work/origin.git"
git -C "$a" remote add origin "$work/origin.git" && gitc "$a" push -q origin main
# Once the remote has the default branch, a push to it is denied; a push of another branch is not.
for c in "git push origin main" "git push" "git push origin HEAD:main" "git -C . push origin feature:refs/heads/main"; do
  hook deny '{"tool_name":"Bash","tool_input":{"command":"'"$c"'"}}'
done
hook allow '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature"}}'
# bash_hook <decision> <command>: the guard hook on a Bash call of the command.
bash_hook() { hook "$1" "$(node -e 'process.stdout.write(JSON.stringify({ tool_name: "Bash", tool_input: { command: process.argv[1] } }))' "$2")"; }
# Quoted text is data: a push inside single quotes, or inside double quotes without $ or a
# backtick, such as a commit message or test data, is no push.
for c in 'git commit -m "docs; git push origin main"' "git commit -m 'a | git push origin main'" \
  "printf '%s\n' \"x && git push origin main\"" $'git commit -m "first line\ngit push origin main"' \
  "echo 'it''s; git push origin main'" "bash -c 'echo git push origin main'" "git push origin 'feature x'"; do
  bash_hook allow "$c"
done
# The forms that the guard before the quote scan denied stay denied: the command string of
# bash -c, sh -c, zsh -c, and eval is a command, adjacent quotes around a word are that word, and
# a push after an operator is seen.
for c in "bash -c 'cd repo && git push origin main'" 'sh -c "git fetch && git push origin main"' "zsh -c 'git push origin main'" \
  "bash -lc 'git push origin main'" "bash -e -c 'git push origin main'" 'eval "git push origin main"' 'eval git push origin main' \
  "git push origin ''main" "git push 'ori'gin \"ma\"in" 'echo x | git push origin main' 'true && git push origin main' \
  'git push origin main &' 'git fetch; git push origin main' 'git -c x=y push origin main' "sudo git push origin main" \
  'X=1 git push origin main' 'command git push origin main' '/usr/bin/git push origin main'; do
  bash_hook deny "$c"
done
# The real forms are still denied: a quoted remote or refspec is still a word, a command
# substitution inside double quotes and a subshell are still seen, and a quote of one kind inside
# the other hides no command; a line continuation joins the lines.
for c in $'git push \\\norigin main' "git push 'origin' 'main'" 'git push origin "main"' 'echo "$(git push origin main)"' 'echo "`git push origin main`"' \
  '(git push origin main)' "echo 'done'; git push origin main" "echo \"a'\" ; git push origin main ; echo \"'b\""; do
  bash_hook deny "$c"
done
# DOCS_GUARD=off passes the push too.
out=$(cd "$a" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | DOCS_GUARD=off CLAUDE_PROJECT_DIR="$a" .claude/hooks/guard.sh 2>&1) &&
  [ -z "$out" ] || fail "guard hook: DOCS_GUARD=off does not pass a push to main: '${out:0:120}'"
# A token in the command must not turn the deny into an approvable prompt.
hook deny '{"tool_name":"Bash","tool_input":{"command":"GH_TOKEN='"$ghp"' git push origin main"}}'
gitc "$a" switch -q -c pushed && printf -- '---\nstatus: proposed\ndate: 2026-01-01\ndecision-makers: test\nscope: stack\nsummary: "Test."\nsupersedes: []\n---\n\n# Test\n' > "$a/docs/decisions/0001-test.md"
(cd "$a" && scripts/gen-decisions-index.sh > docs/decisions/README.md) && gitc "$a" add -A && gitc "$a" commit -q -m record
gitc "$a" push -q -u origin pushed
(cd "$a" && scripts/check-decisions.sh --ready --pr-body "$work/r-none.md" > "$work/pushed.log" 2>&1) &&
  fail "readiness on a pushed feature branch misses the proposed record"
grep -q "0001-test.md: still 'proposed'" "$work/pushed.log" || { cat "$work/pushed.log"; fail "readiness on a pushed feature branch fails for another reason"; }
gitc "$a" switch -q main && gitc "$a" branch -q -D pushed && git -C "$a" remote remove origin
