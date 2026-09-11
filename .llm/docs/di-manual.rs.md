## Dependency Injection

Manual constructor injection — no DI frameworks or service-locator crates.

Group related services into module structs (e.g. `ProtocolModule`, `ServerModule`) that own their services as fields. A module constructs its concrete instances, receiving other modules as constructor parameters.

The binary crate (`nanolimbo/src/main.rs`) is the composition root: it loads configuration, takes ownership of the runtime and the listener, and instantiates all modules in dependency order.

- Prefer generic parameters (static dispatch) over `dyn` trait objects by default; reach for `dyn` deliberately when it removes generic infection across many types, not by habit.
- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons. The Java original used public `static` fields for `PacketSnapshots`; the port must pass that state as an `Arc<PacketSnapshots>` dependency instead.
- `static` is allowed for genuinely constant data (protocol tables, embedded resources) and for the logging subscriber, which is infrastructure, not an application service.
