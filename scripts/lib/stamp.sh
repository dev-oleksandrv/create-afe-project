# Sourced by scripts/check.sh and .claude/hooks/stop-dispatch.sh, in the root of the repository.
# The green stamp: a local cache that lets a check skip a tree it has already passed. CI never
# reads or writes it. There are two kinds, so that a change of one kind does not re-run the checks
# of the other: docs, the Markdown files (*.md), and code, every other path.
# tree_stamps: prints two lines, the code stamp, then the docs stamp. Each is a SHA-256 over the
#   kind's entries (mode, blob, path) in a temporary index that holds the working tree as
#   `git add -A` sees it: a copy of the worktree's index, so the stat cache makes it fast, with
#   ignored files left out, a symbolic link by its target, a submodule or a nested repository by
#   its commit (a nested repository without a commit, or a file git cannot read, is left out, as
#   `git add -A --ignore-errors` leaves it out). It is over content alone, never over HEAD or the real index, so neither `git add`
#   nor `git commit` of the same content changes it, and a commit of one kind leaves the other
#   kind's stamp as it was. `git add` writes the blobs it hashes into a temporary object directory,
#   with the repository's objects as its alternate, so the stamp adds nothing to `.git`.
# tree_stamp <kind>: prints the stamp of one kind, code or docs.
# stamp_read <scope> <kind>: prints the stored stamp of the scope, fast or full, or nothing.
# stamp_write <scope> <kind> [stamp]: stores the stamp, by default the tree's; the files are
#   afe-green-<scope>-<kind> in the worktree's own git directory.
# stamp_matches <scope> <kind> [stamp]: true when the stored stamp of the scope equals the stamp,
#   by default the tree's; for fast, a stored full stamp counts too.
stamp_sha256() {
  if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d ' ' -f 1
}

tree_stamps() {
  local gd idx objs tmp kind
  gd=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 1
  idx=$(git rev-parse --git-path index 2>/dev/null) || return 1
  objs=$(git rev-parse --git-path objects 2>/dev/null) && objs=$(CDPATH= cd "$objs" && pwd) || return 1
  # One temporary directory holds the index and the object directory, so one rm removes both.
  tmp=$(mktemp -d "$gd/afe-stamp.XXXXXX") || return 1
  if [ -f "$idx" ]; then cp "$idx" "$tmp/index"; fi
  mkdir "$tmp/objects"
  GIT_INDEX_FILE=$tmp/index GIT_OBJECT_DIRECTORY=$tmp/objects GIT_ALTERNATE_OBJECT_DIRECTORIES=$objs \
    git -c advice.addEmbeddedRepo=false add -A --ignore-errors > /dev/null 2>&1
  # The listing reads the index alone, never an object.
  for kind in ':(exclude)*.md' '*.md'; do
    GIT_INDEX_FILE=$tmp/index git ls-files -s -z -- "$kind" 2>/dev/null | stamp_sha256
  done
  rm -rf "$tmp"
}

tree_stamp() {
  case "${1:-code}" in
    docs) tree_stamps | sed -n 2p ;;
    *) tree_stamps | sed -n 1p ;;
  esac
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
  [ -n "$s" ] || return 1
  printf '%s\n' "$s" > "$f"
}

stamp_matches() {
  local s="${3:-}" stored
  [ -n "$s" ] || s=$(tree_stamp "$2")
  [ -n "$s" ] || return 1
  stored=$(stamp_read "$1" "$2")
  [ -n "$stored" ] && [ "$stored" = "$s" ] && return 0
  [ "$1" = fast ] && [ "$(stamp_read full "$2")" = "$s" ]
}
