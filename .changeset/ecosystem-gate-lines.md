---
"create-afe-project": minor
---

The seeded `.claude/path-classes` lists the gate files of every ecosystem, one commented block
each: Node.js (with Bun and Deno), Python, Go, Rust, JVM, Ruby, PHP, .NET, Swift, and Dart, with
the `*/` lines for the modules of a monorepo. Before, it named only some manifests of Node.js,
Python, Go, and Rust, so a change to a manifest, lock file, toolchain file, or package-source file
was class normal and missed "Gate files": every one in a JVM, Ruby, PHP, .NET, Swift, Dart, Bun,
or Deno project, such as `pom.xml`, `Gemfile.lock`, `*.csproj`, or `bun.lockb`, and some in
Node.js, Python, Go, and Rust, such as `npm-shrinkwrap.json`, `.npmrc`, `setup.py`, `go.work`, or
`rust-toolchain.toml`. The lines are
ported from agent-docs-template 0.7.0; on the owner's decision of 2026-11-06 every block is
seeded and the `ecosystems` question of that version is not adopted. From the 2.0.0 review, on
the owner's instruction of 2026-11-06. An update never changes a seeded file: an existing project
replaces its block "Dependency manifests and lock files" in `.claude/path-classes` by hand with
the block "Gates of each ecosystem" and the ten ecosystem blocks below it.
