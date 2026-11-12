# An interactive create in a terminal exits after its outro. Needs lib.sh only.
echo "== interactive create in a terminal exits after its outro"
# In a terminal the CLI shows a spinner; create logs more than one step, and a spinner started
# twice keeps a timer alive, so the process never exits. `script` provides the terminal.
if command -v script > /dev/null 2>&1; then
  it="$work/it"
  itcmd=(node "$root/bin/create-afe-project.js" "$it" --data project_name=sample --data 'project_description=A sample project.'
    --data github_repo=example/sample --data ci_runner=github-hosted --data code_review=true
    --data secret_scan=true --data acceptance_check=false --data fail_without_change=false)
  if script --version > /dev/null 2>&1; then
    script -qec "$(printf '%q ' "${itcmd[@]}")" /dev/null > "$work/it.log" 2>&1 < /dev/null &
  else
    script -q /dev/null "${itcmd[@]}" > "$work/it.log" 2>&1 < /dev/null &
  fi
  itpid=$!
  for _ in $(seq 1 240); do grep -q 'is ready' "$work/it.log" 2> /dev/null && break; kill -0 "$itpid" 2> /dev/null || break; sleep 0.25; done
  for _ in $(seq 1 20); do kill -0 "$itpid" 2> /dev/null || break; sleep 0.25; done
  if kill -0 "$itpid" 2> /dev/null; then
    pkill -f "create-afe-project.js $it " 2> /dev/null; kill "$itpid" 2> /dev/null
    fail "interactive create does not exit after its outro"
  else
    grep -q 'is ready' "$work/it.log" && [ -z "$(git -C "$it" status --porcelain 2> /dev/null)" ] &&
      [ "$(git -C "$it" rev-list --count HEAD 2> /dev/null)" = 1 ] || { tail -n 20 "$work/it.log"; fail "interactive create does not finish with the initial commit"; }
  fi
else
  echo "SKIP: script is not installed; the interactive create is not tested"
fi
