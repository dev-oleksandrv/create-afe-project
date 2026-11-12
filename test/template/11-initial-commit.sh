# The initial commit of a new project: --no-git, an empty clone, a forced non-empty directory.
# Needs lib.sh only.
echo "== initial commit: --no-git, an empty clone, a forced non-empty directory"
ng="$work/ng"
cli "$ng" --defaults --quiet --no-git --data project_name=sample --data 'project_description=A sample project.' \
  --data github_repo=example/sample > "$work/ng.log" 2>&1 && [ ! -e "$ng/.git" ] && grep -q 'skipped with --no-git' "$work/ng.log" ||
  { cat "$work/ng.log"; fail "--no-git still initializes Git"; }
ec="$work/ec"
git init -q -b trunk "$ec" && cli "$ec" --defaults --quiet --data project_name=sample --data 'project_description=A sample project.' \
  --data github_repo=example/sample > "$work/ec.log" 2>&1 && [ "$(git -C "$ec" rev-parse --abbrev-ref HEAD)" = main ] &&
  [ -z "$(git -C "$ec" status --porcelain)" ] || { cat "$work/ec.log"; fail "an empty clone does not get the initial commit on main"; }
fd="$work/fd"
mkdir -p "$fd" && echo mine > "$fd/own.txt" && cli "$fd" --defaults --quiet --force --data project_name=sample \
  --data 'project_description=A sample project.' --data github_repo=example/sample > "$work/fd.log" 2>&1 && [ ! -e "$fd/.git" ] &&
  grep -q 'not made here: the directory was not empty' "$work/fd.log" || { cat "$work/fd.log"; fail "a forced non-empty directory is committed"; }
