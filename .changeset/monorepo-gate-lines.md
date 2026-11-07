---
"create-afe-project": patch
---

The seeded `.claude/path-classes` gates the manifests, lock files, toolchain files, and
package-source files of the modules of a monorepo evenly: every ecosystem block now has a `*/` line
next to each root line for a file that a module can have of its own. Before, only some had one, so
a change to a file such as `svc/uv.lock`, `svc/poetry.lock`, `web/yarn.lock`, `web/.npmrc`,
`crates/x/Cargo.lock`, or `ios/Podfile.lock` was class normal and missed "Gate files". Workspace
files (`pnpm-workspace.yaml`, `go.work`, `melos.yaml`), wrappers, tool configuration, and
`global.json`, a name that other files use too, stay gated at the root only. The lines came from
agent-docs-template 0.7.0. From the review of pull request #18, on the owner's instruction of
2026-11-07.

An update never changes a seeded file: an existing project adds these lines to
`.claude/path-classes` by hand, each next to its root line:

- Node.js: `gate */package-lock.json`, `gate */npm-shrinkwrap.json`, `gate */pnpm-lock.yaml`,
  `gate */yarn.lock`, `gate */.yarnrc.yml`, `gate */bun.lock`, `gate */bun.lockb`,
  `gate */deno.json`, `gate */deno.jsonc`, `gate */deno.lock`, `gate */.npmrc`, `gate */.nvmrc`,
  `gate */.node-version`
- Python: `gate */setup.py`, `gate */setup.cfg`, `gate */uv.lock`, `gate */poetry.lock`,
  `gate */requirements*.in`, `gate */Pipfile`, `gate */Pipfile.lock`, `gate */.python-version`
- Rust: `gate */Cargo.lock`, `gate */.cargo/config.toml`, `gate */rust-toolchain`,
  `gate */rust-toolchain.toml`
- JVM: `gate */settings.gradle*`, `gate */gradle.properties`, `gate */gradle/libs.versions.toml`
- Ruby: `gate */.ruby-version`
- .NET: `gate */nuget.config`, `gate */NuGet.Config`, `gate */.config/dotnet-tools.json`
- Swift: `gate */Podfile`, `gate */Podfile.lock`
