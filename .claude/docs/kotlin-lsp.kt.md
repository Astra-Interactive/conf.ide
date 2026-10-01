# Source Code Navigation

### Tool priority

1. `codebase-memory-mcp` — search for symbols, call chains, architecture overview.
2. LSP tool (`kotlin-lsp`) — precise navigation: go-to-definition, references, hover/type info.
3. Bash (`grep`, `find`, `cat`) — last resort only, when the tools above cannot answer.

### Kotlin project source files → `kotlin-lsp` via the LSP tool

Use the built-in **LSP** tool (backed by `kotlin-lsp`) to navigate and inspect Kotlin source files that
are part of this project. The server supports `--stdio` and `--socket` modes — the LSP tool handles
the connection automatically, so never hardcode a socket address.

Dependency sources inside `.jar` files are covered by the `ksrc` rule, not by the LSP.

### When the LSP is not available

There is no fallback. If the LSP tool is missing, `kotlin-lsp` is not installed, or the server fails to
start for this project, stop and ask the user to configure it before continuing with any task that needs
code navigation. Do not substitute `grep`/`find`/`cat` for the missing LSP: text search cannot resolve
types, overloads, or references, and the code you write on top of guesses will be wrong.

Report exactly what failed (tool absent, server binary not found, server error) so the user can fix it.
