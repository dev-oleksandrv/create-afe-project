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
