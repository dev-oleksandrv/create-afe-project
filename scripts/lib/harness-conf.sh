# Sourced by the scripts and hooks that read .claude/harness.conf, from the root of the repository.
# conf_get KEY [default]: prints the value of the last `KEY=value` line of the file, without
# surrounding quotes, or the default when the key is missing or empty. The file is read, never run.
conf_get() {
  local v=
  [ -f .claude/harness.conf ] &&
    v=$(tr -d '\r' < .claude/harness.conf | awk -v k="$1" 'index($0, k "=") == 1 {v = substr($0, length(k) + 2)} END {print v}')
  case "$v" in \"*\") v=${v#\"}; v=${v%\"} ;; \'*\') v=${v#\'}; v=${v%\'} ;; esac
  printf '%s' "${v:-${2:-}}"
}

# matching_files <globs>: prints the tracked and untracked files that match one of the
# space-separated shell globs, in which * also matches /.
matching_files() {
  local f g
  { git ls-files; git ls-files --others --exclude-standard; } | sort -u | while IFS= read -r f; do
    set -f
    for g in $1; do
      # shellcheck disable=SC2254
      case "$f" in $g) printf '%s\n' "$f"; break ;; esac
    done
    set +f
  done
}

# The Ralph loop's cap of the Stop dispatcher (.claude/hooks/stop-dispatch.sh): one count of
# failing stops per Claude Code session and git worktree, in a file of the worktree's own git
# directory named after the session (the hook input's session_id), so an interrupted loop does not
# shorten the next one and two worktrees of one session count apart.
# ralph_block <session> <message>: prints the message; below RALPH_MAX_ITERATIONS failing stops,
# exits 2, which sends the agent back to fix it; at the cap, adds that the cap is reached, resets
# the count, and exits 0, so the agent stops and reports the failure.
# ralph_pass <session>: resets the count.
ralph_count_file() {
  printf '%s/afe-ralph-%s' "$(git rev-parse --absolute-git-dir 2>/dev/null || echo "${TMPDIR:-/tmp}")" \
    "$(printf '%s' "${1:-none}" | tr -c 'A-Za-z0-9_.-' '_')"
}
ralph_block() {
  local f n cap
  f=$(ralph_count_file "$1")
  n=$(( $(cat "$f" 2>/dev/null || echo 0) + 1 ))
  cap=$(conf_get RALPH_MAX_ITERATIONS 2)
  printf '%s\n' "$2" >&2
  if [ "$n" -ge "$cap" ]; then
    rm -f "$f"
    printf 'Ralph loop cap of %s reached: stop now and report the failing command and its output.\n' "$cap" >&2
    exit 0
  fi
  echo "$n" > "$f"
  exit 2
}
ralph_pass() { rm -f "$(ralph_count_file "$1")"; }
