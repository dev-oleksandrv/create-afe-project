# Shared state of the template tests, sourced by scripts/checks.d/10-template.sh from the root of
# the repository before every test file: the work directory, the helpers, and the failure count.
# The templates render with the CLI of this working tree (bin/create-afe-project.js); its
# dependencies come from npm ci when node_modules is missing.
root=$PWD
[ -d node_modules ] || npm ci --silent > /dev/null 2>&1 || { echo "FAIL: npm ci fails"; exit 1; }
cli() { node "$root/bin/create-afe-project.js" "$@"; }

work=$(mktemp -d)
export work
trap 'rm -rf "$work"' EXIT
# The harness hooks do nothing in GitHub Actions; the tests set GITHUB_ACTIONS where they test that.
unset GITHUB_ACTIONS
# DOCS_GUARD=off turns the protect hook and the decisions and template Stop hooks off; inherited,
# it would make their tests fail or pass without testing them.
unset DOCS_GUARD
failures=0
# sj <expression> [argument]: true when the JavaScript expression holds for s, the parsed
# .claude/settings.json of the current directory.
printf '%s\n' '#!/usr/bin/env node' 'const s = JSON.parse(require("fs").readFileSync(".claude/settings.json", "utf8"));' \
  'process.exit(new Function("s", "process", "return (" + process.argv[2] + ");")(s, { argv: process.argv.slice(2) }) ? 0 : 1);' > "$work/sj"
chmod +x "$work/sj"
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
gitc() { git -C "$1" -c user.name=test -c user.email=test@example.com "${@:2}"; }
# The CLI makes the initial commit of a new project with the identity of the environment.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

render() {
  local d="$1"; shift
  cli "$d" --defaults --quiet --data project_name=sample \
    --data 'project_description=A sample project.' --data github_repo=example/sample "$@" \
    > "$work/render.log" 2>&1 || { cat "$work/render.log"; return 1; }
  # The CLI commits the generated files as the only commit on main and leaves a clean tree.
  [ "$(git -C "$d" rev-parse --abbrev-ref HEAD)" = main ] && [ "$(git -C "$d" rev-list --count HEAD)" = 1 ] &&
    [ -z "$(git -C "$d" status --porcelain)" ] && grep -q 'committed on main' "$work/render.log" ||
    { git -C "$d" status --short | head; cat "$work/render.log"; fail "$d: the CLI does not make the initial commit on main"; return 1; }
}
