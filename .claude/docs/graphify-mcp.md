# Graphify MCP

Use Graphify when an answer needs evidence from both documents and code. For example, start from an
architecture decision and find the modules it mentions. For an architecture handoff, export a map
with `graphify export html`. Use `codebase-memory-mcp` for symbol lookup, callers and diff impact.

1. Work in the directory containing the relevant inputs. Reuse its `graphify-out/graph.json` if current.
   Run `GRAPHIFY_BACKEND=none graphify update .` to build or refresh a local graph of code and explicit
   Markdown links. When the question depends on the meaning of prose or PDFs, use `graphify extract .`
   with an explicitly chosen model backend (e.g. `--backend ollama` for a configured local model).
2. Pass that directory's absolute path as `project_path` to the `graphify` MCP tools. Start with
   `query_graph` using a decision title and `demote_docs=false` to remove the document ranking penalty.
   Use `shortest_path` to connect two results.
3. Follow the source references before citing a relationship. An `INFERRED` edge is a lead to verify
   against the document and the implementation.
