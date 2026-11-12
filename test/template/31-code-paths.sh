# The code-path check of scripts/check-links.mjs and the file arguments of scripts/check-docs.sh,
# on variant A. Needs $a from 10-variant-a.sh and expect_fail and expect_pass from 30-negative.sh.
echo "== code paths in the documents of variant A"
# note <file> <text>: a Markdown file with a heading and the text.
note() { mkdir -p "$(dirname "$1")" && printf '# Note\n\n%s\n' "$2" > "$1"; }
export -f note
expect_pass "a backticked path that does not exist fails in docs/, with the file, the line, and the path" bash -c 'note docs/note.md "See \`scripts/nope.sh\`." &&
  out=$(node scripts/check-links.mjs); [ $? -eq 1 ] && printf "%s\n" "$out" | grep -qxF "FAIL: docs/note.md:3: \`scripts/nope.sh\`: no such file or directory"'
expect_pass "a backticked path that does not exist, in AGENTS.md" bash -c 'awk -v l="See \`scripts/nope.sh\`." "{print} /<!-- project:start -->/ {print l}" AGENTS.md > t && mv t AGENTS.md &&
  ! node scripts/check-links.mjs > out.log && grep -q "^FAIL: AGENTS.md:[0-9]*: .scripts/nope.sh.: no such file or directory$" out.log'
expect_pass "a missing directory" bash -c 'note docs/x/note.md "See \`docs/nope/\`." && ! node scripts/check-links.mjs > out.log && grep -q "^FAIL: docs/x/note.md:3: .docs/nope/.: no such" out.log'
expect_pass "a trailing :line, #anchor, or ::name is stripped before the path is checked" bash -c 'note docs/note.md "See \`scripts/check.sh:12\`, \`scripts/check.sh:3:5\`, \`scripts/check-docs.sh#L4\`, \`scripts/env.sh::usage\`, \`scripts/lib/\`, and \`.claude/path-classes\`." &&
  node scripts/check-links.mjs'
expect_pass "the stripped path is named when it does not exist" bash -c 'note docs/note.md "See \`scripts/nope.sh:12\`." &&
  node scripts/check-links.mjs | grep -qxF "FAIL: docs/note.md:3: \`scripts/nope.sh\`: no such file or directory"'
expect_pass "tokens that are not path candidates are ignored" bash -c 'note docs/note.md "Push \`origin/main\` to \`owner/name\`; \`a/b\` and \`x/y.sh\` name no root entry; \`docs/*.md\` is a glob, \`docs/<name>.md\` and \`scripts/{x}.sh\` and \`\$HOME/scripts/x\` are placeholders, \`https://example.com/scripts/x\` has a scheme, \`scripts/nope.sh --flag\` has whitespace, \`/scripts/x\` starts at no root entry, \`scripts/a|b\` is a pipe." &&
  node scripts/check-links.mjs'
expect_pass "a path in a fenced code block is not checked" bash -c 'printf "# Note\n\n\x60\x60\x60sh\nscripts/nope.sh \x60scripts/nope.sh\x60\n\x60\x60\x60\n" > docs/note.md && node scripts/check-links.mjs'
expect_pass "Markdown outside docs/ and AGENTS.md is not checked for code paths" bash -c 'note note.md "See \`scripts/nope.sh\`." && mkdir -p src && note src/README.md "See \`scripts/nope.sh\`." && node scripts/check-links.mjs'
expect_pass "a code path is checked in a file given as an argument, relative or absolute" bash -c 'note docs/note.md "See \`scripts/nope.sh\`." &&
  ! node scripts/check-links.mjs docs/note.md > out.log && grep -q "^FAIL: docs/note.md:3: " out.log &&
  ! node scripts/check-links.mjs "$PWD/docs/note.md" > out.log && grep -q "^FAIL: docs/note.md:3: " out.log'

echo "== scripts/check-docs.sh with file arguments on variant A"
# docs/bad.md fails markdownlint (no space after the heading mark), docs/dead.md the link check;
# docs/good.md passes both.
bad() { printf '# Bad\n\n#Not a heading\n' > docs/bad.md; printf '# Dead\n\nSee [x](nope.md).\n' > docs/dead.md; note docs/good.md 'Fine.'; }
export -f bad
expect_fail "without arguments, every Markdown file is checked" bash -c 'bad && scripts/check-docs.sh'
expect_pass "with a file argument, only that file is linted and link-checked" bash -c 'bad && scripts/check-docs.sh docs/good.md'
expect_fail "a file argument that fails markdownlint" bash -c 'bad && scripts/check-docs.sh docs/good.md docs/bad.md'
expect_pass "a file argument that fails the link check, named in the output" bash -c 'bad && out=$(scripts/check-docs.sh docs/dead.md 2>&1); [ $? -ne 0 ] && printf "%s\n" "$out" | grep -q "FAIL: docs/dead.md:3: nope.md"'
expect_fail "a file argument relative to the current directory" bash -c 'bad && cd docs && ../scripts/check-docs.sh bad.md'
expect_pass "arguments without an existing Markdown file check nothing" bash -c 'bad && scripts/check-docs.sh scripts/check.sh docs/gone.md | grep -q "no Markdown file among the arguments"'
mkdir -p "$work/nonode" && ln -sf "$(command -v bash)" "$work/nonode/bash" && ln -sf "$(command -v dirname)" "$work/nonode/dirname"
(cd "$a" && PATH="$work/nonode" scripts/check-docs.sh docs/decisions/adr-template.md > "$work/nonode.log" 2>&1); [ $? -eq 3 ] && grep -q 'MISSING TOOL: node' "$work/nonode.log" ||
  { cat "$work/nonode.log"; fail "check-docs.sh with file arguments: a missing tool does not exit 3"; }
