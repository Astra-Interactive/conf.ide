# Rust imports guidelines

- Never use wildcard imports: not `use foo::*`, not `use Status::*`, not a crate's `prelude::*`, not
  `use super::*` in a test. Import each item by name; a trait that a prelude would bring is imported by name too
  (`use std::io::Read;`).
- Always use explicit imports.
- The imports of a file are one block at its top, with no blank line and no comment inside it, in the order
  `cargo fmt` gives: rustfmt sorts a block of consecutive `use` lines (`self::`, `super::`, `crate::` first, then
  every crate alphabetically, `std` among them). Put a new import anywhere in the block and run `cargo fmt`. A
  comment line splits the block into runs that rustfmt sorts separately, as a blank line does. A comment at the
  end of a `use` line is not allowed either: the one on the last line of the block stays in place when rustfmt
  reorders and ends up on a different import, and one rule holds for every position. A comment about an import
  goes above the block.
- When the project's `rustfmt.toml` sets another import order (`reorder_imports = false`), that order wins.
  Kotlin's layout groups (`java`, `javax`, `kotlin`) have no stable rustfmt counterpart: `group_imports` is
  nightly-only, and the notes rule keeps the project on stable.

```rust
use crate::invoice::model::Invoice;
use serde::Deserialize;
use std::collections::HashMap;
use std::fmt::Write as _;
use tokio::sync::watch;
```
