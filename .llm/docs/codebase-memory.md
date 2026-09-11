# Codebase Navigation

To navigate the codebase and project files you must use `codebase-memory-mcp`.

## Make sure the server is connected

The `mcp__codebase-memory-mcp__*` tools must be available before any code exploration. If they are not:

1. Check whether the server is registered: `claude mcp list`.
2. If it is missing, register the `codebase-memory-mcp` binary at user scope and reconnect:

   ```
   claude mcp add --scope user codebase-memory-mcp <path-to>/codebase-memory-mcp
   ```

   Then reload MCP servers in the current session (`/mcp`) or restart Claude Code.
3. If the binary itself is not installed, stop and ask the user to install it. Do not fall back to
   `ls`/`grep`/`find` for code exploration while the server is unavailable.

## Keep the index up-to-date

Before navigating the codebase you must update the project index so the knowledge graph reflects the current state of the code:

1. Check the project with `index_status` (run `list_projects` if you are not sure the project is registered).
2. If the project is not registered or not indexed yet, run `index_repository` on the repository root.
3. If the project is indexed, run `detect_changes` to verify whether the working tree has changed since
   the last indexing (new branch, fresh pull, local edits). Re-index with `index_repository` only when it
   reports changes; do not re-index a large repository unconditionally.

Never explore stale graph data — re-index first, then navigate.

## Navigation tools

Always prefer `codebase-memory-mcp` tools over plain `ls`/`grep`/`find` for code exploration:

- `search_graph` — find functions, classes, and routes by name pattern, label, or qualified-name pattern.
- `trace_path` — trace call chains and data flow (`mode=calls|data_flow|cross_service`).
- `get_code_snippet` — read the exact source of a symbol by its qualified name.
- `query_graph` — complex Cypher queries over the code graph.
- `get_architecture` — project structure overview.
- `search_code` — graph-augmented text search across the codebase.

`Grep`/`Glob`/`Read` are acceptable only for non-code files (configs, docs, resources) and for reading a file before editing it.
