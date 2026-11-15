---
"create-afe-project": minor
---

`update` stays inside the project, shows local edits before it replaces them, and can be run again
after a failure.

- Paths: before it changes anything, `update` checks every path it reads, writes, or removes:
  each entry of `.template/owned.txt` and `.template/owned.sha256`, each file the template
  writes, and each file its tasks regenerate afterwards (`.claude/settings.json`,
  `.template/owned.sha256`). An absolute path, a `..` or empty component, or a symbolic link on the way stops the
  update with a message that names the entry, and nothing has been changed. Before, a `../` entry
  of an old `.template/owned.txt` deleted a file outside the project and pruned its directory, and
  a symbolic link at a template-owned file was written through and had its mode changed. The
  pruning of empty directories stops below the project root. A seeded file that is a symbolic
  link, such as `CLAUDE.md` pointing to `AGENTS.md`, stays as it is. `create --force` checks the
  paths it writes in the same way.
- Local edits: before it changes anything, `update` lists the template-owned files whose content
  differs from the hash in `.template/owned.sha256`, which the update replaces or removes, and the
  files it removes. In a terminal it asks whether to go on; with `--defaults` it prints each local
  edit as a `Warning:` line, which the `update-template` skill lists for the owner, and goes on.
- Failures: `update` records the new version in `.afe-answers.json` last, after the migrations and
  the regeneration of the generated files succeeded. Before, it recorded the version before the
  migrations, so a migration that failed was skipped by the next update. A failed update keeps the
  recorded version and says how to resume: run the same update again with `--allow-dirty`, which
  runs the migrations again. The migrations run with `set -euo pipefail`: a failing command of the
  3.0.0 migration now fails the update instead of being ignored, and each migration is safe to run
  a second time. No migration writes through a symbolic link: a seeded file that is one stays as
  it is, with a `Warning:` line that names the change by hand, and temporary files go to the
  update's own directory, never next to their target.
- 4.0.0: the update from 3.x reports, as `Warning:` lines, the two steps by hand of 4.0.0 where
  they apply: a `.claude/hooks/project/stop/*.sh` that `.claude/settings.project.json` does not
  register under `hooks.Stop`, and `FWC_INSTALL` or `FWC_CLASSIFIER` left in
  `.claude/harness.conf`. It changes neither.

The failures these fix were found by two independent reviews of the harness on 2026-11-15, not in
a pull request: an update that deletes or writes outside the project (reproduced with a `../`
entry), and a failed migration recorded as a success, so that the next update skips it. The
checks are added on the owner's decision of 2026-11-15.
