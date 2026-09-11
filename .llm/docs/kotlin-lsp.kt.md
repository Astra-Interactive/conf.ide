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
