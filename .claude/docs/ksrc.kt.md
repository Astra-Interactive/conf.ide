## Dependency sources → `ksrc`

Use the **`ksrc`** CLI to read and search source code that lives inside Gradle dependency `.jar` files.
Never access `.gradle` directly, and never use `jar tf`, `jar xf`, `unzip` or similar shell commands to
inspect `.jar` contents. Start with `ksrc --help` if unsure.

```
# Search for a symbol/snippet across dependency sources
ksrc search <pattern> [--module <:subproject>] [--artifact <group:artifact>]

# Read a specific file by its file-id (returned by `ksrc search`)
ksrc cat <group:artifact:version!/path/inside/jar.kt>

# List resolved dependencies and check source availability
ksrc deps [--module <:subproject>]

# Ensure sources are downloaded for a coordinate
ksrc fetch <group:artifact:version>
```

When you need to understand an external library's API:

1. `ksrc search` for a symbol or snippet.
2. `ksrc cat` with the returned file-id to read the full source.
3. `ksrc deps` if you are not sure which artifact contains the symbol.
