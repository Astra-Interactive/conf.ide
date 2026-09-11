# Source Code Navigation

### Rust project source files → `rust-analyzer` via the LSP tool
Use the built-in **LSP** tool (backed by `rust-analyzer`) to navigate and inspect Rust source files that
are part of this workspace. The server communicates over stdio — the LSP tool handles the connection
automatically, so never spawn or configure the server manually:
- Go-to-definition, find references, hover/type info, symbol search.
- Resolving trait implementations and generic bounds — especially valuable for `Buf`/`BufMut` extension
  traits and for the project's own ports.
- Do **not** use `grep`/`find`/`cat` as a substitute when the LSP can answer the question directly.

### Dependency (crate) sources → cargo cache
Source code of every resolved dependency is already on disk. Use `cargo` to locate and read it:

```
# List resolved dependencies and versions
cargo tree

# Find where a crate's sources live on disk
cargo metadata --format-version 1 | python3 -c "import json,sys; [print(p['manifest_path']) for p in json.load(sys.stdin)['packages'] if p['name'] == '<crate>']"

# Search a crate's sources for a symbol/snippet
grep -rn "<symbol>" ~/.cargo/registry/src/*/<crate>-<version>/src/
```

Registry crates live under `~/.cargo/registry/src/`; git dependencies live under `~/.cargo/git/checkouts/`.

### Searching for dependency API shapes
When you need to understand an external crate's API:
1. Get the crate's source path via `cargo metadata` (or find it in the cargo cache).
2. Grep/read the sources directly for the symbol you need.
3. Fall back to `cargo doc -p <crate>` or docs.rs for the exact dependency version if reading sources is not enough.
