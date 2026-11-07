---
"create-afe-project": patch
---

`scripts/protect-branch.sh` handles the errors of a plan without rulesets or Advanced Security.
When GitHub refuses the list of rulesets with HTTP 403 or 404, as it does for a private
repository on GitHub Free, the script says that the settings are applied and the rule rests on
the owner and review, and ends without error; before, it stopped with the raw `gh` error. It
reads all pages of the list and only the repository's own rulesets (`includes_parents=false`),
so it no longer misses its ruleset past the first page or picks one of the same name inherited
from an organisation. Secret scanning refused by the plan still warns and goes on. Any other
secret-scanning error (a missing permission, an invalid payload, no connection) is printed with
the `gh` output; the ruleset is still applied, then the script fails and names that error again
in its last line. It fails also when the list of rulesets then returns HTTP 403 or 404, after
the message on rulesets. `--dry-run` is unchanged. An update replaces the file; an existing
project does nothing by hand. From the 2.0.0 review, on the owner's instructions of 2026-11-06
and 2026-11-07.
