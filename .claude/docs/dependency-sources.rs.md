## Dependency sources → cargo cache

Do not guess an external crate's API. The source code of every resolved dependency is already on disk:
registry crates live under `~/.cargo/registry/src/`, git dependencies under `~/.cargo/git/checkouts/`.

```
# List resolved dependencies and versions
cargo tree

# Find where a crate's sources live on disk
cargo metadata --format-version 1 | python3 -c "import json,sys; [print(p['manifest_path']) for p in json.load(sys.stdin)['packages'] if p['name'] == '<crate>']"

# Search a crate's sources for a symbol/snippet
grep -rn "<symbol>" ~/.cargo/registry/src/*/<crate>-<version>/src/
```

When you need to understand an external crate's API:

1. Get the crate's source path via `cargo metadata`.
2. Read the sources for the symbol you need.
3. Fall back to `cargo doc -p <crate>` or docs.rs for the exact dependency version only when the sources do not answer the question.

Project source files are covered by the rust-lsp rule, not by this one.
