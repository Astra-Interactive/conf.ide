# Rust imports guidelines

- Never use wildcard imports (e.g., `use foo::*`)
- Always use explicit imports
- Imports should be sorted alphabetically, grouped as: `core`/`std` first, then external crates, then `crate`/`super`/`self`
- Allowed exceptions for wildcards:
    - a crate's documented prelude when it is the intended way to consume the crate
    - `use super::*;` inside `#[cfg(test)] mod tests`
