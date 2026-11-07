---
"create-afe-project": minor
---

The protect hook (`.claude/hooks/protect-docs.sh`) asks the owner before more commands that
change a repository for good: `gh repo edit` in any form (visibility, merge methods, default
branch, branch deletion, and the other settings), `gh repo rename`, and `gh repo archive`; and a
GraphQL mutation through `gh api graphql`, a `query=` field (`-f`, `-F`, `--field`, or
`--raw-field`) that holds the keyword `mutation`. When the hook cannot read the query, from
`-F query=@file`, `--input`, a shell expansion such as `query="$(cat q.graphql)"`, or a quoted
query over several lines (the hook reads a command line by line), it asks too and says so in its
reason; a read-only query over several lines therefore asks as well. A `gh api` endpoint given
as a full URL (`https://api.github.com/graphql`, `https://HOST/api/v3/repos/...`) is now judged
like its path. `gh repo view` and the other read-only `gh repo` subcommands, and a
GraphQL query without a mutation, still pass. `docs/documentation-rules.md`, section 8, now names
every command class the hook asks on, condensed to stay within the file's 200 lines. A command
split across lines with `\`, or behind `env`, `time`, or `nohup`, is still not detected, as the
hook's header says. An existing project gets both files with the template update and does nothing
by hand; a headless run (CI) that runs one of these commands through Claude Code is now denied.
Added on the owner's instruction of 2026-11-07, round 2 of the 2.0.0 review fixes.
