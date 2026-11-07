---
"create-afe-project": patch
---

The rule documents now match the 2.0.1 migration, which can replace an existing seeded file such
as a default `.claude/harness.conf` or `.claude/path-classes`. `docs/contributing.md`, section 5,
said that an update never changes an existing seeded file and leaves project files untouched; it
now says that an update changes an existing seeded or project file only through a migration
that the update report and the changelog name (2.0.1 also removes `.harness/`). The Seeded row of
`docs/documentation-rules.md`, section 9, and step 4 of the `update-template` skill say the same.
These files are template-owned, so an existing project gets the new wording on its next update,
with nothing to do by hand. From the 2.0.1 docs review, on the owner's instruction of 2026-11-07.
