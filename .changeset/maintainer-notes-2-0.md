---
"create-afe-project": patch
---

Erratum for the 2.0.0 entry of `CHANGELOG.md`, which stays as released. First, the entry of #6
(`.claude/hooks/stop-check-fast.sh`) says that an existing project may "copy those two lines by
hand"; the comment that names the hook in the seeded `.claude/harness.conf` is three lines,
starting with the line "Once set to something other than scripts/check-docs.sh". Second, the
same entry is listed under Minor Changes, but a Stop hook that blocks on a failing `CHECK_FAST`
is a stricter check that existing content can fail, which `docs/maintaining.md`, section 4, makes
MAJOR; the 2.0.0 release is MAJOR anyway, so only the label was wrong. No file of a generated
project changes and no project needs to act. From the 2.0.0 review, on the owner's instruction
of 2026-11-06.
