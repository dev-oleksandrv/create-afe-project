# This repository's template-owned files match a render of template/ with its answers. Needs
# lib.sh only.
echo "== this repository matches template/"
self="$work/self"
cli "$self" --defaults --quiet --data-file .afe-answers.json > "$work/self.log" 2>&1 ||
  { cat "$work/self.log"; fail "this repository's answers do not render"; }
strip() { awk '$0=="<!-- project:start -->" {print; s=1; next} $0=="<!-- project:end -->" {s=0} !s' "$1"; }
while IFS= read -r p; do
  case "$p" in ''|'#'*) continue ;; esac
  if [ "$p" = AGENTS.md ]; then
    [ "$(strip AGENTS.md)" = "$(strip "$self/AGENTS.md")" ] || fail "AGENTS.md differs from template/; run scripts/sync-self.sh"
  else
    cmp -s "$p" "$self/$p" || fail "$p differs from template/; run scripts/sync-self.sh"
  fi
done < "$self/.template/owned.txt"
