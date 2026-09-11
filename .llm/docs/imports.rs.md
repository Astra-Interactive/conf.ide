# Rust imports guidelines

- Never use wildcard imports (e.g., `use foo::*`)
- Always use explicit imports
- Imports form three groups separated by one blank line, in this order:
    1. `std` / `core` / `alloc`
    2. external crates
    3. `crate` / `super` / `self`
- Within a group the order is whatever `cargo fmt` produces; run it and do not fight it
- Allowed exceptions for wildcards:
    - a crate's documented prelude when it is the intended way to consume the crate
    - `use super::*;` inside `#[cfg(test)] mod tests`

### Why the groups are kept by hand

Stable `rustfmt` sorts imports only within a block of consecutive `use` lines and never moves a `use`
across a blank line, so the three groups survive formatting. The option that would build the groups
automatically, `group_imports = "StdExternalCrate"`, is nightly-only, and the notes rule keeps the
project on stable. When adding an import, put it into the right group; `cargo fmt` takes care of the
position inside it.
