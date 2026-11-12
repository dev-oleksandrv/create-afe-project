# The pull request description template in both variants. Needs $a from 10-variant-a.sh and $b
# from 13-variant-b.sh.
echo "== pull request description template in both variants"
# The sections of the description template (docs/contributing.md, section 3), in order; a
# description built from them, with "None" in each list section and the template's own Metrics
# tables, passes the readiness check on a change without diff.
expected=$'Summary\nAcceptance and test plan\nChecks\nAssumptions and open questions\nOwner decisions\nGate files\nMetrics\nNotes for the owner'
for v in a b; do
  d="$work/$v"
  got=$(awk '/^```markdown$/ {f=1; next} /^```$/ {f=0} f && /^## / {sub(/^## /, ""); print}' "$d/docs/contributing.md")
  [ "$got" = "$expected" ] || fail "variant $v: description template sections are '$(printf '%s' "$got" | tr '\n' '|')'"
  awk '/^```markdown$/ {f=1; next} /^```$/ {f=0} !f {next}
    /^## / {s = substr($0, 4); print $0 "\n"; if (s == "Acceptance and test plan") print "- None: no behaviour change\n"; else if (s != "Metrics") print "- None\n"; next}
    s == "Metrics" && /^\|/ {print} s == "Metrics" && /^$/ {print}' "$d/docs/contributing.md" > "$work/$v-body.md"
  (cd "$d" && scripts/check-decisions.sh --ready --base main --pr-body "$work/$v-body.md" > "$work/$v-ready.log" 2>&1) ||
    { cat "$work/$v-ready.log"; fail "variant $v: readiness rejects a description in the template's sections"; }
done
