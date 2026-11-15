# Sourced by scripts/check-project.sh, scripts/env.sh, and .claude/hooks/stop-dispatch.sh, from the
# root of the repository, after scripts/lib/harness-conf.sh. The lock of a scarce resource of the
# machine, such as Docker, opt-in: CHECK_LOCK of .claude/harness.conf names it, and every checkout
# and project of the user on the machine that sets the same name shares it; empty, nothing locks.
# The lock is the file afe-lock-<uid>-<name> in the user's temporary directory (TMPDIR, else /tmp),
# the owner record of its holder: the pid, the start time of that process (ps), so that a reused
# pid does not count as the holder, and what the holder runs, in which directory. A taker writes
# its record to a file of its own next to it and takes the lock with one hard link of that file to
# the lock (ln, which fails when the lock exists), so the lock has its owner from the first
# instant; nobody rewrites a record after that.
# check_lock <what>: takes the lock for the rest of the calling script and exports AFE_CHECK_LOCK,
#   so that a process the holder starts does not wait for its own ancestor. It returns at once when
#   CHECK_LOCK is empty or such an ancestor holds the lock. A lock whose holder no longer runs, or
#   whose record cannot be read, is stale: a waiter moves it aside under a name of its own, removes
#   it when it is the lock it judged (the same file), and otherwise puts it back, or gives up this
#   attempt when another lock took its place meanwhile. A waiter prints one line on stderr and
#   waits up to CHECK_LOCK_WAIT seconds (default 900); then it names the holder on stderr and
#   returns 1. The holder releases the lock on exit and on HUP, INT, and TERM (bash runs the trap
#   once the command in the foreground ends); a holder killed with KILL leaves it to the takeover.
# check_lock_busy: true when CHECK_LOCK is set and a running process other than an ancestor holds
#   the lock.

lock_path() {
  printf '%s/afe-lock-%s-%s' "${TMPDIR:-/tmp}" "$(id -u)" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"
}

lock_started() { ps -o lstart= -p "$1" 2> /dev/null | tr -s ' '; }

# lock_state <file>: prints the holder's pid; status 0 when it runs, 1 when it does not or the
# record cannot be read, 2 when there is no lock.
lock_state() {
  local pid= started= now
  [ -e "$1" ] || [ -L "$1" ] || return 2
  { IFS= read -r pid; IFS= read -r started; } < "$1" 2> /dev/null
  printf '%s' "$pid"
  case "$pid" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2> /dev/null || return 1
  now=$(lock_started "$pid")
  [ -z "$started" ] || [ -z "$now" ] || [ "$now" = "$started" ]
}

# lock_who <file>: the holder for a message.
lock_who() {
  local pid started what
  { IFS= read -r pid; IFS= read -r started; IFS= read -r what; } < "$1" 2> /dev/null ||
    { echo "a process that has just released it"; return; }
  printf 'pid %s (%s)' "$pid" "$what"
}

# lock_id <file>: the inode of the file, which a takeover compares (the lock and the files moved
# aside share its directory).
lock_id() { ls -di "$1" 2> /dev/null | awk '{print $1}'; }

lock_release() {
  [ -n "${lock_held:-}" ] || return 0
  [ "$(lock_state "$lock_held")" = "$$" ] && rm -f "$lock_held"
  lock_held=
}

# lock_take <file> <what>: one attempt at the lock; true when this process holds it.
lock_take() {
  local l=$1 rec id aside
  rec=$(mktemp "$l.rec.XXXXXX") || return 1
  printf '%s\n%s\n%s\n' "$$" "$(lock_started "$$")" "$2" > "$rec"
  if [ ! -d "$l" ] && ln "$rec" "$l" 2> /dev/null; then
    rm -f "$rec"
    lock_held=$l
    export AFE_CHECK_LOCK="$l:$$"
    trap lock_release EXIT
    trap 'lock_release; exit 129' HUP
    trap 'lock_release; exit 130' INT
    trap 'lock_release; exit 143' TERM
    return 0
  fi
  rm -f "$rec"
  # Judge the lock, then move aside exactly the file that was judged stale.
  id=$(lock_id "$l")
  [ -n "$id" ] || return 1
  lock_state "$l" > /dev/null && return 1
  [ $? = 1 ] || return 1
  aside=$(mktemp "$l.aside.XXXXXX") || return 1
  mv -f "$l" "$aside" 2> /dev/null || { rm -f "$aside"; return 1; }
  if [ "$(lock_id "$aside")" = "$id" ]; then
    rm -f "$aside"
  elif ! ln "$aside" "$l" 2> /dev/null; then
    echo "== the lock $l changed hands during a takeover and could not be put back; its holder $(lock_who "$aside") no longer holds it" >&2
    rm -f "$aside"
  else
    rm -f "$aside"
  fi
  return 1
}

check_lock() {
  local name l wait waited=0 said=
  name=$(conf_get CHECK_LOCK)
  [ -n "$name" ] || return 0
  l=$(lock_path "$name")
  [ -n "${AFE_CHECK_LOCK:-}" ] && [ "$AFE_CHECK_LOCK" = "$l:$(lock_state "$l")" ] && return 0
  if [ -d "$l" ]; then
    echo "FAIL: $l is a directory, not the lock $name (CHECK_LOCK of .claude/harness.conf); remove it" >&2
    return 1
  fi
  wait=$(conf_get CHECK_LOCK_WAIT 900)
  case "$wait" in *[!0-9]*) wait=900 ;; esac
  while :; do
    lock_take "$l" "${1:-a check} in $PWD" && return 0
    # Released or taken over just now: try again at once.
    [ -e "$l" ] || continue
    if [ "$waited" -ge "$wait" ]; then
      echo "FAIL: the lock $name (CHECK_LOCK of .claude/harness.conf) is still held after $wait seconds, by $(lock_who "$l"); let that check finish or stop it, or raise CHECK_LOCK_WAIT" >&2
      return 1
    fi
    if [ -z "$said" ]; then
      echo "== waiting up to $wait seconds for the lock $name (CHECK_LOCK of .claude/harness.conf), held by $(lock_who "$l")" >&2
      said=1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

check_lock_busy() {
  local name l pid
  name=$(conf_get CHECK_LOCK)
  [ -n "$name" ] || return 1
  l=$(lock_path "$name")
  pid=$(lock_state "$l") || return 1
  [ "${AFE_CHECK_LOCK:-}" != "$l:$pid" ]
}
