# The pull request description in both variants. Needs $a from 10-variant-a.sh and $b from
# 13-variant-b.sh.
echo "== pull request description sections in both variants"
# A description with the four sections of the create-pr skill passes the readiness check on a
# change without diff, with or without the acceptance_check module.
printf '## Summary\n\n- x\n\n## Acceptance and test plan\n\n- None: no behaviour change\n\n## Checks\n\n- scripts/check.sh passed\n\n## Open questions\n\nNone\n' > "$work/sections-body.md"
for v in a b; do
  d="$work/$v"
  (cd "$d" && scripts/check-decisions.sh --ready --base main --pr-body "$work/sections-body.md" > "$work/$v-ready.log" 2>&1) ||
    { cat "$work/$v-ready.log"; fail "variant $v: readiness rejects a description with the four sections"; }
done
