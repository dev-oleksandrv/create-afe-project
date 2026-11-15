# The lock of CHECK_LOCK (scripts/lib/lock.sh) around scripts/check-project.sh and
# scripts/env.sh fast|e2e, and the Stop dispatcher while another process holds it. Needs $a from
# 10-variant-a.sh and stop from 61-hooks-ralph.sh. The locks live in $work/locks (TMPDIR).
echo "== the lock of a scarce resource (CHECK_LOCK)"
gd=$(git -C "$a" rev-parse --absolute-git-dir)
grep -qx 'CHECK_LOCK=' "$a/.claude/harness.conf" && grep -qx 'CHECK_LOCK_WAIT=900' "$a/.claude/harness.conf" ||
  fail "harness.conf: CHECK_LOCK is not empty, or CHECK_LOCK_WAIT is not 900, by default"
tmp_keep=${TMPDIR-unset}
export TMPDIR="$work/locks"
mkdir -p "$TMPDIR"
ldir="$TMPDIR/afe-lock-$(id -u)-afetest"
conf() { sed -i.bak "s#^$1=.*#$1=$2#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"; }
# took <what>: waits up to 5 seconds for a holder's owner file.
took() { local i=0; until [ -f "$ldir/owner" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done; [ -f "$ldir/owner" ] || fail "lock: $1 does not take the lock"; }
# Without CHECK_LOCK nothing locks.
conf CHECK_FAST "ls $TMPDIR > $work/lock.seen"
(cd "$a" && scripts/env.sh fast > "$work/lock.log" 2>&1) && [ ! -s "$work/lock.seen" ] ||
  { cat "$work/lock.log" "$work/lock.seen"; fail "lock: env.sh fast takes a lock without CHECK_LOCK"; }
conf CHECK_LOCK afetest && conf CHECK_LOCK_WAIT 1 && conf E2E "touch $work/e2e.ran"
mkdir -p "$a/scripts/checks.d" && printf '#!/usr/bin/env bash\ntouch "%s/project.ran"\n' "$work" > "$a/scripts/checks.d/20-x.sh" &&
  chmod +x "$a/scripts/checks.d/20-x.sh"
# A holder: env.sh fast runs until a flag file appears, for 10 seconds at most.
conf CHECK_FAST "for i in \$(seq 100); do [ -e $work/lock.go ] || sleep 0.1; done"
(cd "$a" && scripts/env.sh fast > "$work/holder.log" 2>&1) &
holder=$!
took "env.sh fast"
hp=$(sed -n 1p "$ldir/owner" 2> /dev/null)
# The others wait CHECK_LOCK_WAIT seconds with one line, then fail naming the holder, and run nothing.
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1); [ $? -eq 1 ] && [ ! -e "$work/e2e.ran" ] &&
  [ "$(grep -c '^== waiting up to 1 seconds for the lock afetest' "$work/lock.log")" = 1 ] &&
  grep -q "^FAIL: the lock afetest (CHECK_LOCK of .claude/harness.conf) is still held after 1 seconds, by pid $hp (scripts/env.sh fast in " "$work/lock.log" ||
  { cat "$work/lock.log"; fail "lock: env.sh e2e does not wait, then fail naming the holder, or runs anyway"; }
(cd "$a" && scripts/check-project.sh > "$work/lock.log" 2>&1); [ $? -eq 1 ] && [ ! -e "$work/project.ran" ] && grep -q "still held after 1 seconds, by pid $hp" "$work/lock.log" ||
  { cat "$work/lock.log"; fail "lock: check-project.sh does not wait for the lock, or runs its checks anyway"; }
# A sub-agent's Stop skips the fast check with one line and stores no code stamp; the main agent's
# Stop waits for the lock as any check does.
echo x > "$a/src.txt" && rm -f "$gd"/afe-green-* "$gd"/afe-ralph-*
pd= stop '{"session_id":"lock","agent_id":"w1","hook_event_name":"SubagentStop","cwd":"'"$a"'"}'
[ $? -eq 0 ] && [ "$(wc -l < "$work/stop.log" | tr -d ' ')" = 1 ] && grep -q 'the fast check is skipped while another process holds the lock afetest' "$work/stop.log" &&
  grep -q "the agent's own checks and the next Stop cover the change" "$work/stop.log" && [ ! -e "$gd/afe-green-fast-code" ] ||
  { cat "$work/stop.log"; fail "stop-dispatch: a sub-agent's Stop runs the fast check while another process holds the lock, says more than one line, or stores the code stamp"; }
stop '{"session_id":"lock"}'; [ $? -eq 2 ] && grep -q 'still held after 1 seconds' "$work/stop.log" ||
  { cat "$work/stop.log"; fail "stop-dispatch: the main agent's Stop does not wait for the lock"; }
touch "$work/lock.go" && wait "$holder"
[ ! -e "$ldir" ] || fail "lock: the holder does not release the lock on exit"
# Free again: the waiter runs; without a holder the sub-agent's Stop runs the fast check.
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: env.sh e2e does not run, or keeps the lock, once it is free"; }
rm -f "$gd"/afe-ralph-*
pd= stop '{"session_id":"lock","agent_id":"w1","hook_event_name":"SubagentStop","cwd":"'"$a"'"}'
[ $? -eq 0 ] && [ -f "$gd/afe-green-fast-code" ] && ! grep -q skipped "$work/stop.log" ||
  { cat "$work/stop.log"; fail "stop-dispatch: a sub-agent's Stop skips the fast check without a holder"; }
# A process that the holder starts does not wait for it: a project check that runs env.sh fast.
conf CHECK_FAST "echo inner-ran" && printf '#!/usr/bin/env bash\nscripts/env.sh fast\n' > "$a/scripts/checks.d/20-x.sh"
(cd "$a" && scripts/check-project.sh > "$work/lock.log" 2>&1) && grep -qx inner-ran "$work/lock.log" && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: a check under the lock waits for its own ancestor"; }
# A holder that no longer runs, or a lock without an owner file, is taken over.
rm -f "$work/e2e.ran"
sh -c 'exit 0' &
dead=$!
wait "$dead"; mkdir "$ldir" && printf '%s\n\nscripts/env.sh fast in /gone\n' "$dead" > "$ldir/owner"
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: a lock whose holder no longer runs is not taken over"; }
rm -f "$work/e2e.ran" && mkdir "$ldir" && conf CHECK_LOCK_WAIT 10
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: a lock without an owner file is not taken over"; }
# A taker that died after its takeover marker, with or without the marker's owner file, does not
# block the next waiter.
rm -f "$work/e2e.ran" && mkdir -p "$ldir/takeover" && printf '%s\n\nscripts/env.sh fast in /gone\n' "$dead" > "$ldir/owner" &&
  printf '%s\n\ntaking over\n' "$dead" > "$ldir/takeover/owner"
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: the takeover marker of a taker that no longer runs blocks the lock"; }
rm -f "$work/e2e.ran" && mkdir -p "$ldir/takeover" && printf '%s\n\nscripts/env.sh fast in /gone\n' "$dead" > "$ldir/owner"
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: a takeover marker without an owner file blocks the lock"; }
# A taker whose lock directory is taken over before its owner file is written does not hold the
# lock: it tries again. The takeover is simulated by a ps that removes the directory once, when the
# taker reads its own start time for the owner file.
rm -rf "$ldir" && mkdir -p "$work/fakeps" && printf '#!/usr/bin/env bash
[ -e "%s/ps.once" ] && rm -rf "%s" "%s/ps.once"
exec /bin/ps "$@"
' "$work" "$ldir" "$work" > "$work/fakeps/ps" &&
  chmod +x "$work/fakeps/ps" && touch "$work/ps.once" && conf E2E "test -f $ldir/owner"
(cd "$a" && PATH="$work/fakeps:$PATH" scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ ! -e "$work/ps.once" ] && [ ! -e "$ldir" ] ||
  { cat "$work/lock.log"; fail "lock: a taker that lost its directory before its owner file believes that it holds the lock"; }
conf E2E "touch $work/e2e.ran"
# A signal releases the lock once the command in the foreground ends.
rm -rf "$ldir" && conf CHECK_FAST "sleep 1"
(cd "$a" && exec scripts/env.sh fast > "$work/holder.log" 2>&1) &
holder=$!
took "env.sh fast before the signal"
kill -TERM "$holder"; wait "$holder"; code=$?
[ "$code" = 143 ] && [ ! -e "$ldir" ] || { cat "$work/holder.log"; fail "lock: TERM does not release the lock (exit $code)"; }
rm -rf "$ldir" "$a/src.txt" "$a/scripts/checks.d" "$work/lock.go" "$work/e2e.ran" "$work/project.ran" "$gd"/afe-green-* "$gd"/afe-ralph-*
gitc "$a" checkout -q -- .claude/harness.conf
if [ "$tmp_keep" = unset ]; then unset TMPDIR; else export TMPDIR="$tmp_keep"; fi
