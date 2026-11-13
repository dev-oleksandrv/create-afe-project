# Sourced by scripts/check.sh and .claude/hooks/stop-dispatch.sh, in the root of the repository.
# The green stamp: a local cache that lets a check skip a tree it has already passed. CI never
# reads or writes it. There are two kinds, so that a change of one kind does not re-run the checks
# of the other: docs, the Markdown files (*.md), and code, every other path.
# tree_stamp <kind>: prints a SHA-256 over the content of the kind's files, never over HEAD, so a
#   commit of one kind leaves the other kind's stamp as it was: the index's blob listing of the
#   kind's tracked paths (`git ls-files -s`), the working tree's difference from the index
#   (`git diff`, binary-safe), and the path and content hash of each untracked, non-ignored file of
#   the kind (a symbolic link counts by its target), in that order.
# stamp_read <scope> <kind>: prints the stored stamp of the scope, fast or full, or nothing.
# stamp_write <scope> <kind> [stamp]: stores the stamp, by default the tree's; the files are
#   afe-green-<scope>-<kind> in the worktree's own git directory.
# stamp_matches <scope> <kind> [stamp]: true when the stored stamp of the scope equals the stamp,
#   by default the tree's; for fast, a stored full stamp counts too.
stamp_sha256() {
  if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d ' ' -f 1
}

# stamp_pathspec <kind>: prints the git pathspec of the kind.
stamp_pathspec() {
  case "$1" in
    docs) printf '%s' '*.md' ;;
    *) printf '%s' ':(exclude)*.md' ;;
  esac
}

tree_stamp() {
  local spec f
  spec=$(stamp_pathspec "${1:-code}")
  {
    git -c core.quotePath=false ls-files -s -z -- "$spec" 2>/dev/null
    git -c core.quotePath=false diff --binary --no-ext-diff --no-textconv -- "$spec" 2>/dev/null
    # The untracked paths, NUL-separated, so that no name is quoted; then a symbolic link's target;
    # then the content hash of each regular file, in as few git calls as xargs makes, as one
    # process per file would make the stamp slow. An empty list hashes nothing.
    local untracked=()
    while IFS= read -r -d '' f; do untracked+=("$f"); done < <(git ls-files -z --others --exclude-standard -- "$spec" 2>/dev/null)
    if [ "${#untracked[@]}" -gt 0 ]; then
      printf '%s\0' "${untracked[@]}"
      for f in "${untracked[@]}"; do
        if [ -L "$f" ]; then printf 'link %s -> %s\0' "$f" "$(readlink "$f")"; fi
      done
      for f in "${untracked[@]}"; do
        if [ -f "$f" ] && [ ! -L "$f" ]; then printf '%s\0' "$f"; fi
      done | xargs -0 git hash-object -- 2>/dev/null
    fi
  } | stamp_sha256
}

stamp_file() {
  local dir
  dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 1
  printf '%s/afe-green-%s-%s' "$dir" "$1" "$2"
}

stamp_read() {
  local f
  f=$(stamp_file "$1" "$2") && [ -f "$f" ] && cat "$f"
  return 0
}

stamp_write() {
  local f s="${3:-}"
  f=$(stamp_file "$1" "$2") || return 1
  [ -n "$s" ] || s=$(tree_stamp "$2")
  printf '%s\n' "$s" > "$f"
}

stamp_matches() {
  local s="${3:-}" stored
  [ -n "$s" ] || s=$(tree_stamp "$2")
  stored=$(stamp_read "$1" "$2")
  [ -n "$stored" ] && [ "$stored" = "$s" ] && return 0
  [ "$1" = fast ] && [ "$(stamp_read full "$2")" = "$s" ]
}
