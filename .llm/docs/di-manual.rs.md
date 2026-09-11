## Dependency Injection

Manual constructor injection — no DI frameworks or service-locator crates.

Group related services into module structs (e.g. `DomainModule`, `InfrastructureModule`) that own their
services as fields. A module constructs its concrete instances and receives other modules as constructor
parameters.

The binary crate's `main.rs` is the composition root: it loads configuration, owns the entry-point
resources (the async runtime, listeners, connection pools, file handles), and instantiates all modules in
dependency order. A library crate exposes a constructor for its top-level module and leaves the wiring to
the binary that uses it.

- Prefer generic parameters (static dispatch) over `dyn` trait objects by default; reach for `dyn`
  deliberately when it removes generic infection across many types, not by habit.
- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons. State shared between tasks is passed down as an
  `Arc<T>` dependency, never read from a `static`.
- `static` is allowed for genuinely constant data (lookup tables, embedded resources) and for the logging
  subscriber, which is infrastructure, not an application service.
