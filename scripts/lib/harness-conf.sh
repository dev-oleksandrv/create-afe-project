# Sourced by the scripts that read .claude/harness.conf (docs/contributing.md, section 3).
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

# The Ralph loop's cap in the Stop hooks (docs/contributing.md, section 3). ralph_block <name>
# <message>: below RALPH_MAX_ITERATIONS failing stops of hook <name>, prints the message and
# exits 2, which sends the agent back to fix it; at the cap, prints the message and that the cap
# is reached, resets the count, and exits 0, so the agent stops and reports the failure.
# ralph_pass <name>: resets the count when the hook's check passes. The counts live in the git
# directory, one file per hook and Claude Code session (RALPH_SESSION, the hook input's
# session_id), so an interrupted loop does not shorten the next one.
ralph_count_file() { printf '%s/ralph-stops-%s-%s' "$(git rev-parse --git-dir 2>/dev/null || echo /tmp)" "${RALPH_SESSION:-none}" "$1"; }
ralph_block() {
  local f n cap
  f=$(ralph_count_file "$1")
  n=$(( $(cat "$f" 2>/dev/null || echo 0) + 1 ))
  cap=$(conf_get RALPH_MAX_ITERATIONS 5)
  printf '%s\n' "$2" >&2
  if [ "$n" -ge "$cap" ]; then
    rm -f "$f"
    printf 'Ralph loop cap of %s reached: stop now and report the failing command and its output (docs/contributing.md, section 3).\n' "$cap" >&2
    exit 0
  fi
  echo "$n" > "$f"
  exit 2
}
ralph_pass() { rm -f "$(ralph_count_file "$1")"; }
