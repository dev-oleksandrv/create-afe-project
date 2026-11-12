# Sourced by the hooks in .claude/hooks/ (all but guard.sh, which runs no file of the working tree).
# resolve_root <cwd> [file]: prints the top level of the git repository that holds the file when
# one is given, otherwise the one that holds cwd, with symbolic links resolved. A relative file is
# joined to cwd; a file or directory that does not exist yet is judged by its nearest existing
# parent. Without such a repository it falls back to CLAUDE_PROJECT_DIR, then to the top level of
# the current directory's repository. Prints nothing and returns 1 when none applies. A git
# worktree is a repository of its own here, so a hook judges a sibling worktree by its own files.
resolve_root() {
  local cwd="${1:-}" file="${2:-}" dir top
  [ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
  dir=$cwd
  if [ -n "$file" ]; then
    case "$file" in /*) dir=$(dirname "$file") ;; *) dir=$(dirname "$cwd/$file") ;; esac
    while [ ! -d "$dir" ]; do dir=$(dirname "$dir"); done
  fi
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) ||
    top=${CLAUDE_PROJECT_DIR:-}
  [ -n "$top" ] && [ -d "$top" ] || top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  (cd "$top" 2>/dev/null && pwd -P)
}
