---
"create-afe-project": patch
---

`.claude/hooks/post-edit-check.sh` resolves a relative `file_path` against the `cwd` of the hook
input, the session's working directory, instead of the project root, so `CHECK_EDIT` checks the
file the agent edited. Ported from agent-docs-template 0.7.0 on the owner's instruction of
2026-11-05.
