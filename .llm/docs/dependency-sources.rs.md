## Searching for dependencies

Avoid guessing external crate APIs; instead, proactively inspect dependency source code from the cargo cache (`~/.cargo/registry/src/` for registry crates, `~/.cargo/git/checkouts/` for git dependencies) to learn API shapes or implementations. Use `cargo tree` to see resolved versions and `cargo metadata` to get exact source paths.

This matters most for the NBT and YAML crates, whose docs are thin and whose exact behaviour (named vs nameless compounds, field ordering) the wire format depends on.
