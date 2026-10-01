## Dependency Injection

Manual constructor injection — no DI frameworks or service-locator crates.

Group related services into DI module structs (e.g. `WhitelistModule`) that own their services as fields. A DI
module constructs its concrete instances and receives other DI modules as constructor parameters. Every DI module
lives in the `di` module of the concept it wires (`src/di/whitelist_module.rs`); it is `pub` only when another
crate constructs it.

The composition root is `RootModule` in `src/di/root_module.rs` of the binary crate: it loads configuration,
owns the entry-point resources (the async runtime, listeners, connection pools, file handles), and instantiates
all DI modules in dependency order. The same file holds `pub fn run() -> ExitCode`, which builds `RootModule` and
starts the application; `src/main.rs` only calls it:

```rust
// src/main.rs
fn main() -> std::process::ExitCode {
    limbo::di::run()
}
```

A library crate exposes a constructor for its top-level DI module and leaves the wiring to the binary that uses it.

- Prefer generic parameters (static dispatch) over `dyn` trait objects by default; reach for `dyn`
  deliberately when it removes generic infection across many types, not by habit.
- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons. State shared between tasks is passed down as an
  `Arc<T>` dependency, never read from a `static`.
- `static` is allowed for genuinely constant data (lookup tables, embedded resources) and for the logging
  subscriber, which is infrastructure, not an application service.
