# Source Code Navigation

### Tool priority

1. `codebase-memory-mcp` — search for symbols, call chains, architecture overview.
2. LSP tool (`rust-analyzer`) — precise navigation: go-to-definition, references, hover/type info, trait implementations.
3. Bash (`grep`, `find`, `cat`) — last resort only, when the tools above cannot answer.

### Rust project source files → `rust-analyzer` via the LSP tool

Use the built-in **LSP** tool (backed by `rust-analyzer`) to navigate and inspect Rust source files that
are part of this workspace. The server communicates over stdio — the LSP tool handles the connection
automatically, so never spawn or configure the server manually. It is the tool for resolving trait
implementations and generic bounds, which text search cannot answer.

Dependency (crate) sources are covered by the dependency-sources rule, not by the LSP.

### When the LSP is not available

There is no fallback. If the LSP tool is missing, `rust-analyzer` is not installed, or the server fails
to start for this workspace, stop and ask the user to configure it before continuing with any task that
needs code navigation. Do not substitute `grep`/`find`/`cat` for the missing LSP: text search cannot
resolve trait implementations, generic bounds, or references, and the code you write on top of guesses
will be wrong.

Report exactly what failed (tool absent, server binary not found, server error) so the user can fix it.
