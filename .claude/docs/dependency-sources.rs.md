## Dependency sources → `cargo` and codebase-memory

Read and search the source code of an external crate in the copy Cargo has unpacked for the version the
lockfile resolved, through `codebase-memory-mcp`, as project code is. Its directory comes from `cargo metadata`:
never a path guessed under the Cargo home (it moves with `CARGO_HOME`, and it holds several versions of a crate),
never a `.crate` archive from `registry/cache` unpacked by hand, and never a crate downloaded or cloned only to
read it. `grep`, `rg`, `find` and `cat` stay off dependency sources as off project code (`codebase-memory.md`).

```
# List the resolved dependencies of the workspace, of one crate, or the crates that pull in a dependency
cargo tree [-p <member>] [-i <crate>]

# Download the sources of every resolved dependency
cargo fetch

# The manifest of a dependency, for the version the lockfile resolved; its directory holds the sources
cargo metadata --format-version 1 --locked | python3 -I -c "import json,sys; [print(p['manifest_path']) for p in json.load(sys.stdin)['packages'] if p['name'] == '<crate>']"
```

When you need to understand an external crate's API:

1. `cargo metadata` for the crate's directory. Two lines mean two resolved versions: `cargo tree -i <crate>`
   says which one the crate you work on uses. When `--locked` fails, the lockfile is out of date: say so to the
   user instead of updating it.
2. Index that directory: codebase-memory's `index_repository` with `repo_path` set to it and `mode` `fast`. The
   result names the project (`…-<crate>-<version>`). A registry crate never changes, so a version indexed once
   is not indexed again; `index_status` on the project name says whether it is.
3. Search that project: `search_graph` for a symbol by name (`name_pattern`), `search_code` for a snippet or a
   doc-comment text, then `get_code_snippet` with the qualified name a search returned to read the source.
4. Fall back to `cargo doc -p <crate> --no-deps` or docs.rs for the exact resolved version only when the sources
   do not answer the question.

Project source files are covered by the rust-lsp rule, not by this one.
