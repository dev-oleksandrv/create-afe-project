# Sourced by scripts/check-project.sh, scripts/env.sh, and .claude/hooks/stop-dispatch.sh, from the
# root of the repository, after scripts/lib/harness-conf.sh. The lock of a scarce resource of the
# machine, such as Docker, opt-in: CHECK_LOCK of .claude/harness.conf names it, and every checkout
# and project of the user on the machine that sets the same name shares it; empty, nothing locks.
# The lock is the directory afe-lock-<uid>-<name> in the user's temporary directory (TMPDIR, else
# /tmp); its file owner holds the holder's pid, the start time of that process (ps), so that a
# reused pid does not count as the holder, and what the holder runs, in which directory.
# check_lock <what>: takes the lock for the rest of the calling script and exports AFE_CHECK_LOCK,
#   so that a process the holder starts does not wait for its own ancestor. It returns at once when
#   CHECK_LOCK is empty or such an ancestor holds the lock. A lock whose holder is no longer
#   running, or that has no owner file after 3 seconds, is taken over. A waiter prints one line on
#   stderr and waits up to CHECK_LOCK_WAIT seconds (default 900); then it names the holder on
#   stderr and returns 1. The holder releases the lock on exit and on HUP, INT, and TERM (bash runs
#   the trap once the command in the foreground ends); a holder killed with KILL leaves it to the
#   takeover.
# check_lock_busy: true when CHECK_LOCK is set and a running process other than an ancestor holds
#   the lock, or is taking it.

lock_dir() {
  printf '%s/afe-lock-%s-%s' "${TMPDIR:-/tmp}" "$(id -u)" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"
}

lock_started() { ps -o lstart= -p "$1" 2> /dev/null | tr -s ' '; }

# lock_state <dir>: prints the holder's pid; status 0 when it runs, 1 when it does not, 2 when the
# directory has no owner file (being taken, or left by a holder that died at once).
lock_state() {
  local pid= started= now
  [ -f "$1/owner" ] || return 2
  { IFS= read -r pid; IFS= read -r started; } < "$1/owner" 2> /dev/null
  printf '%s' "$pid"
  case "$pid" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2> /dev/null || return 1
  now=$(lock_started "$pid")
  [ -z "$started" ] || [ -z "$now" ] || [ "$now" = "$started" ]
}

# lock_who <dir>: the holder for a message.
lock_who() {
  local pid started what
  { IFS= read -r pid; IFS= read -r started; IFS= read -r what; } < "$1/owner" 2> /dev/null ||
    { echo "a process that is taking it"; return; }
  printf 'pid %s (%s)' "$pid" "$what"
}

lock_release() {
  [ -n "${lock_held:-}" ] || return 0
  [ "$(lock_state "$lock_held")" = "$$" ] && rm -rf "$lock_held"
  lock_held=
}

check_lock() {
  local name d wait pid st waited=0 said= misses=0
  name=$(conf_get CHECK_LOCK)
  [ -n "$name" ] || return 0
  d=$(lock_dir "$name")
  [ -n "${AFE_CHECK_LOCK:-}" ] && [ "$AFE_CHECK_LOCK" = "$d:$(lock_state "$d")" ] && return 0
  wait=$(conf_get CHECK_LOCK_WAIT 900)
  case "$wait" in *[!0-9]*) wait=900 ;; esac
  while :; do
    if mkdir "$d" 2> /dev/null; then
      printf '%s\n%s\n%s in %s\n' "$$" "$(lock_started "$$")" "${1:-a check}" "$PWD" > "$d/owner.$$" &&
        mv -f "$d/owner.$$" "$d/owner"
      lock_held=$d
      export AFE_CHECK_LOCK="$d:$$"
      trap lock_release EXIT
      trap 'lock_release; exit 129' HUP
      trap 'lock_release; exit 130' INT
      trap 'lock_release; exit 143' TERM
      return 0
    fi
    pid=$(lock_state "$d")
    st=$?
    [ "$st" = 2 ] && misses=$((misses + 1))
    # A holder that does not run, or no owner file for 3 polls: one waiter at a time takes it over,
    # after it reads the same holder again.
    if [ "$st" = 1 ] || { [ "$st" = 2 ] && [ "$misses" -ge 3 ]; }; then
      if mkdir "$d/takeover" 2> /dev/null; then
        if [ "$(lock_state "$d")" = "$pid" ] && ! lock_state "$d" > /dev/null; then
          rm -rf "$d"
          continue
        fi
        rmdir "$d/takeover" 2> /dev/null
      fi
    fi
    if [ "$waited" -ge "$wait" ]; then
      echo "FAIL: the lock $name (CHECK_LOCK of .claude/harness.conf) is still held after $wait seconds, by $(lock_who "$d"); let that check finish or stop it, or raise CHECK_LOCK_WAIT" >&2
      return 1
    fi
    if [ -z "$said" ]; then
      echo "== waiting up to $wait seconds for the lock $name (CHECK_LOCK of .claude/harness.conf), held by $(lock_who "$d")" >&2
      said=1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

check_lock_busy() {
  local name d pid
  name=$(conf_get CHECK_LOCK)
  [ -n "$name" ] || return 1
  d=$(lock_dir "$name")
  [ -d "$d" ] || return 1
  pid=$(lock_state "$d")
  case $? in 0) ;; 2) return 0 ;; *) return 1 ;; esac
  [ "${AFE_CHECK_LOCK:-}" != "$d:$pid" ]
}
