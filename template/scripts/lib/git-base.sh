# Sourced by scripts/check-decisions.sh, scripts/fail-without-change.sh, the Stop hooks
# .claude/hooks/stop-check-docs.sh and .claude/hooks/stop-check-fast.sh, and
# .claude/hooks/session-start.sh.
# resolve_base [ref] prints the commit that the current change is compared with:
# - with a ref: the merge base of that ref and HEAD; an unknown ref is an error (status 2);
# - without: the merge base with the first of origin/HEAD, origin/main, and main that exists (the
#   branch a pull request goes into, never the current branch's own upstream); else HEAD (only
#   uncommitted changes count); else, in a repository without commits, the empty tree.
resolve_base() {
  local ref
  if [ -n "${1:-}" ]; then
    git rev-parse --verify -q "$1^{commit}" >/dev/null || { echo "unknown base ref '$1'" >&2; return 2; }
    git merge-base "$1" HEAD
    return
  fi
  for ref in origin/HEAD origin/main main; do
    git rev-parse --verify -q "$ref^{commit}" >/dev/null 2>&1 || continue
    git merge-base "$ref" HEAD 2>/dev/null && return 0
  done
  if git rev-parse --verify -q HEAD >/dev/null; then
    git rev-parse HEAD
  else
    git hash-object -t tree /dev/null
  fi
}
