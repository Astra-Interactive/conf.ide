# Source Code Navigation

### Tool priority

1. `codebase-memory-mcp` — search for symbols, call chains, architecture overview.
2. `kotlin-lsp` through an available LSP client — precise navigation: go-to-definition, references,
   hover/type info.

Text search in code goes through codebase-memory's `search_code`; `grep`/`find`/`cat` are for non-code files
only, and for reading a file before editing it (`codebase-memory.md`).

### Kotlin project source files → `kotlin-lsp`

Use `kotlin-lsp` when navigating Kotlin source needs precise types, overload resolution or references.
Prefer a dedicated LSP tool when the current agent exposes one. A working server installation does not
mean that every agent session exposes such a tool.

When no dedicated tool is exposed, use an LSP client through the terminal to communicate with the installed
`kotlin-lsp` over `--stdio`. This is an allowed way to use the same server, without asking the user for an
exception to this rule. The client must initialize the project, open the relevant Kotlin file and complete
the required LSP request; starting the executable or reading `--help` does not verify project navigation.
Let a dedicated tool manage its own connection; never guess or hardcode a socket address.

Dependency sources inside `.jar` files are covered by the `ksrc` rule, not by the LSP.

### When LSP navigation is not available

First distinguish a missing dedicated tool, a missing server executable and a failed project connection.
Check that `kotlin-lsp` is on `PATH`, try the available client, and inspect the initialization or request
error. Restart the connection if the client allows it. Do not ask the user to reinstall or reconnect the
server merely because the session has no dedicated LSP tool.

If no client can complete the required request, report exactly what failed and what you tried. Continue
independent work supported by `codebase-memory-mcp` and verified source. Stop only the part that requires
unavailable type, overload or reference information; do not guess it or treat text matches as semantic
resolution. The text-search restrictions above still apply.
