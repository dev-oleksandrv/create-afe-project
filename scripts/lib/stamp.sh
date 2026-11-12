# Sourced by scripts/check.sh and .claude/hooks/stop-dispatch.sh, in the root of the repository.
# The green stamp: a local cache that lets a check skip a tree it has already passed. CI never
# reads or writes it.
# tree_stamp: prints a SHA-256 over HEAD (empty without a commit), `git diff HEAD` (binary-safe;
#   against the empty tree without a commit), and the path and content hash of each untracked,
#   non-ignored file, in that order (a symbolic link counts by its target).
# stamp_read <scope>: prints the stored stamp of the scope, fast or full, or nothing.
# stamp_write <scope> [stamp]: stores the stamp, by default the tree's; the files are
#   afe-green-<scope> in the worktree's own git directory.
# stamp_matches <scope> [stamp]: true when the stored stamp of the scope equals the stamp, by
#   default the tree's; for fast, a stored full stamp counts too.
stamp_sha256() {
  if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d ' ' -f 1
}

tree_stamp() {
  local head base f
  head=$(git rev-parse -q --verify HEAD 2>/dev/null) && base=HEAD || base=$(git hash-object -t tree /dev/null)
  {
    printf '%s\n' "$head"
    git -c core.quotePath=false diff --binary --no-ext-diff --no-textconv "$base" -- 2>/dev/null
    # The untracked paths, NUL-separated, so that no name is quoted; then a symbolic link's target;
    # then the content hash of each regular file, in as few git calls as xargs makes, as one
    # process per file would make the stamp slow. An empty list hashes nothing.
    git ls-files -z --others --exclude-standard 2>/dev/null
    git ls-files -z --others --exclude-standard 2>/dev/null | while IFS= read -r -d '' f; do
      if [ -L "$f" ]; then printf 'link %s -> %s\0' "$f" "$(readlink "$f")"; fi
    done
    git ls-files -z --others --exclude-standard 2>/dev/null | while IFS= read -r -d '' f; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then printf '%s\0' "$f"; fi
    done | xargs -0 git hash-object -- 2>/dev/null
  } | stamp_sha256
}

stamp_file() {
  local dir
  dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 1
  printf '%s/afe-green-%s' "$dir" "$1"
}

stamp_read() {
  local f
  f=$(stamp_file "$1") && [ -f "$f" ] && cat "$f"
  return 0
}

stamp_write() {
  local f s="${2:-}"
  f=$(stamp_file "$1") || return 1
  [ -n "$s" ] || s=$(tree_stamp)
  printf '%s\n' "$s" > "$f"
}

stamp_matches() {
  local s="${2:-}" stored
  [ -n "$s" ] || s=$(tree_stamp)
  stored=$(stamp_read "$1")
  [ -n "$stored" ] && [ "$stored" = "$s" ] && return 0
  [ "$1" = fast ] && [ "$(stamp_read full)" = "$s" ]
}
