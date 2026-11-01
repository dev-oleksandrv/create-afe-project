# Changesets

Every change a user of `create-afe-project` can notice needs a changeset: a file here that names
the version bump and says what changed. It becomes the `CHANGELOG.md` entry and the release
notes. Create one with `npx changeset`; for a change of `bin/`, `src/`, `template/`, or
`package.json` that nobody notices, `npx changeset --empty`. The rules for the bump and the text
are in [`docs/maintaining.md`](../docs/maintaining.md), sections 2 and 4.
