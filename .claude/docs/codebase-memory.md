# Codebase Navigation

Use the installed `codebase-memory` skill for structural exploration, callers and impact analysis.
Prefer graph and LSP tools for relationships. Use direct reads for known files and text search for
literals, resources, configuration and graph coverage gaps, within the agent's tool permissions.

## Make sure the server is connected

When graph tools are unavailable, use permitted LSP, reads and search for the task's question. Report
any resulting coverage limit. Configure or reconnect a server when that is requested or when the answer
depends on graph capabilities unavailable elsewhere.

## Keep the index up-to-date

The investigation owner establishes graph freshness for the repository and relevant revision once:

1. Check the project with `index_status` (run `list_projects` if you are not sure the project is registered).
2. If the project is not registered or not indexed yet, run `index_repository` on the repository root.
3. If the project is indexed, run `detect_changes` to verify whether the working tree has changed since
   the last indexing (new branch, fresh pull, local edits). Re-index with `index_repository` only when it
   reports changes; do not re-index a large repository unconditionally.

Pass the project ID, root and indexed revision to other agents using that evidence. Recheck after changes
that affect the relationship being queried. A known current source file can be read directly while an
index is updating. Confirm graph findings against the current source before changing behavior.

## Navigation tools

For structural questions prefer:

- `search_graph` — find functions, classes, and routes by name pattern, label, or qualified-name pattern.
- `trace_path` — trace call chains and data flow (`mode=calls|data_flow|cross_service`).
- `get_code_snippet` — read the exact source of a symbol by its qualified name.
- `query_graph` — complex Cypher queries over the code graph.
- `get_architecture` — project structure overview.
- `search_code` — graph-augmented text search across the codebase.

Respect the agent's available tools. A read-only agent's shell guard
(`.claude/hooks/readonly-guard.sh`) allows shell search only in its `docs` and `gradle` modes; in the others
the agent reads non-code files with its file-read tool.
