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
lk="$TMPDIR/afe-lock-$(id -u)-afetest"
conf() { sed -i.bak "s#^$1=.*#$1=$2#" "$a/.claude/harness.conf" && rm "$a/.claude/harness.conf.bak"; }
# took <what>: waits up to 5 seconds for a holder's lock file.
took() { local i=0; until [ -f "$lk" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done; [ -f "$lk" ] || fail "lock: $1 does not take the lock"; }
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
hp=$(sed -n 1p "$lk" 2> /dev/null)
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
[ ! -e "$lk" ] || fail "lock: the holder does not release the lock on exit"
# Free again: the waiter runs; without a holder the sub-agent's Stop runs the fast check.
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$lk" ] ||
  { cat "$work/lock.log"; fail "lock: env.sh e2e does not run, or keeps the lock, once it is free"; }
rm -f "$gd"/afe-ralph-*
pd= stop '{"session_id":"lock","agent_id":"w1","hook_event_name":"SubagentStop","cwd":"'"$a"'"}'
[ $? -eq 0 ] && [ -f "$gd/afe-green-fast-code" ] && ! grep -q skipped "$work/stop.log" ||
  { cat "$work/stop.log"; fail "stop-dispatch: a sub-agent's Stop skips the fast check without a holder"; }
# A process that the holder starts does not wait for it: a project check that runs env.sh fast.
conf CHECK_FAST "echo inner-ran" && printf '#!/usr/bin/env bash\nscripts/env.sh fast\n' > "$a/scripts/checks.d/20-x.sh"
(cd "$a" && scripts/check-project.sh > "$work/lock.log" 2>&1) && grep -qx inner-ran "$work/lock.log" && [ ! -e "$lk" ] ||
  { cat "$work/lock.log"; fail "lock: a check under the lock waits for its own ancestor"; }
# A holder that no longer runs, or a lock whose record cannot be read, is taken over; files that a
# taker left aside do not count.
rm -f "$work/e2e.ran"
sh -c 'exit 0' &
dead=$!
wait "$dead"; printf '%s\n\nscripts/env.sh fast in /gone\n' "$dead" > "$lk" && cp "$lk" "$lk.aside.left"
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$lk" ] ||
  { cat "$work/lock.log"; fail "lock: a lock whose holder no longer runs is not taken over"; }
rm -f "$work/e2e.ran" "$lk.aside.left" && : > "$lk"
(cd "$a" && scripts/env.sh e2e > "$work/lock.log" 2>&1) && [ -e "$work/e2e.ran" ] && [ ! -e "$lk" ] ||
  { cat "$work/lock.log"; fail "lock: a lock with an empty record is not taken over"; }
# The races of a taker, made deterministic by a ps that pauses or acts once: the lock scripts call
# ps for the start time of a process.
mkdir -p "$work/fakeps" && cat > "$work/fakeps/ps" <<PS
#!/usr/bin/env bash
# Pauses while ps.hold exists, after it touches ps.entered.
if [ -e "$work/ps.hold" ]; then touch "$work/ps.entered"; while [ -e "$work/ps.hold" ]; do sleep 0.1; done; fi
# Once, when asked about the pid in ps.swap, puts the record ps.new in place of the lock.
if [ -e "$work/ps.swap" ] && [ "\$*" = "-o lstart= -p \$(cat "$work/ps.swap")" ]; then
  rm "$work/ps.swap"; cp "$work/ps.new" "$lk.new" && mv -f "$lk.new" "$lk"
fi
exec /bin/ps "\$@"
PS
chmod +x "$work/fakeps/ps"
# A delayed creator: a taker that pauses while it writes its record, while another process takes
# the lock, takes nothing when it resumes, and leaves the record of the holder as it is.
rm -f "$work/e2e.ran" "$work/lock.go" && touch "$work/ps.hold" && conf CHECK_LOCK_WAIT 10
(cd "$a" && PATH="$work/fakeps:$PATH" scripts/env.sh e2e > "$work/late.log" 2>&1) &
late=$!
i=0; until [ -e "$work/ps.entered" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
conf CHECK_FAST "for i in \$(seq 100); do [ -e $work/lock.go ] || sleep 0.1; done; [ ! -e $work/e2e.ran ]"
(cd "$a" && scripts/env.sh fast > "$work/holder.log" 2>&1) &
holder=$!
i=0; until [ -f "$lk" ] && grep -q 'scripts/env.sh fast' "$lk" || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
hp=$(sed -n 1p "$lk" 2> /dev/null)
rm -f "$work/ps.hold" && sleep 1
[ ! -e "$work/e2e.ran" ] && [ "$(sed -n 1p "$lk" 2> /dev/null)" = "$hp" ] && grep -q 'scripts/env.sh fast' "$lk" ||
  { cat "$work/late.log"; fail "lock: a delayed creator takes the lock of another holder, or rewrites its record"; }
touch "$work/lock.go"; wait "$holder"; hcode=$?; wait "$late"; lcode=$?
[ "$hcode" = 0 ] && [ "$lcode" = 0 ] && [ -e "$work/e2e.ran" ] && [ ! -e "$lk" ] ||
  { cat "$work/holder.log" "$work/late.log"; fail "lock: two processes held the lock at once, or the delayed creator does not run after the holder (exits $hcode, $lcode)"; }
rm -f "$work/ps.entered"
# A lock that changes hands during a takeover: while a taker judges a stale lock (a running pid with
# another start time), another holder takes its place; the taker puts that lock back, waits for
# it, and does not run.
sleep 30 &
live=$!
printf '%s\nMon Jan  1 00:00:00 2001\nscripts/env.sh fast in /reused\n' "$live" > "$lk"
printf '%s\n%s\nscripts/env.sh fast in /replacement\n' "$live" "$(/bin/ps -o lstart= -p "$live" | tr -s ' ')" > "$work/ps.new"
printf '%s' "$live" > "$work/ps.swap" && rm -f "$work/e2e.ran" && conf CHECK_LOCK_WAIT 1
(cd "$a" && PATH="$work/fakeps:$PATH" scripts/env.sh e2e > "$work/lock.log" 2>&1); code=$?
[ "$code" = 1 ] && [ ! -e "$work/ps.swap" ] && [ ! -e "$work/e2e.ran" ] && grep -q 'scripts/env.sh fast in /replacement' "$lk" &&
  grep -q "still held after 1 seconds, by pid $live (scripts/env.sh fast in /replacement)" "$work/lock.log" ||
  { cat "$work/lock.log" "$lk"; fail "lock: a takeover removes a lock that changed hands since it was judged stale (exit $code)"; }
kill "$live"; wait "$live" 2> /dev/null; rm -f "$lk" "$lk".*
# A signal releases the lock once the command in the foreground ends.
rm -f "$lk" && conf CHECK_FAST "sleep 1"
(cd "$a" && exec scripts/env.sh fast > "$work/holder.log" 2>&1) &
holder=$!
took "env.sh fast before the signal"
kill -TERM "$holder"; wait "$holder"; code=$?
[ "$code" = 143 ] && [ ! -e "$lk" ] || { cat "$work/holder.log"; fail "lock: TERM does not release the lock (exit $code)"; }
rm -rf "$lk" "$lk".* "$a/src.txt" "$a/scripts/checks.d" "$work/lock.go" "$work/e2e.ran" "$work/project.ran" "$gd"/afe-green-* "$gd"/afe-ralph-*
gitc "$a" checkout -q -- .claude/harness.conf
if [ "$tmp_keep" = unset ]; then unset TMPDIR; else export TMPDIR="$tmp_keep"; fi
