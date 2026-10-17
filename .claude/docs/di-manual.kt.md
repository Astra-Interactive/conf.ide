## Dependency Injection

Manual constructor injection — no Koin, Dagger, or other DI frameworks.

A DI module is a Kotlin `class` (e.g. `LinkModule`) that declares its services as properties, constructs
their concrete instances, and receives other DI modules as constructor parameters. Use a class by default.
Make a DI module an `interface` with a separate implementation only when it has to be extended or split into
api/impl. "DI module" names this class only; a Gradle module is a build unit.

`RootModule` is the composition root: the one DI module per application that builds the root DI modules in
dependency order, using `lazy {}` where construction must be deferred. It lives in `di/RootModule.kt` of the
unit that starts the application (`instances:<name>`, the plugin unit), next to the entry point that creates it.

- DI modules form a tree that follows the unit dependencies. Each unit that constructs something has its
  own DI module in the `di/`
  package of the level it wires (`…command.di.CommandModule`, `…gui.api.rating.di.RatingGuiModule`). A
  resource with its own lifecycle, such as a database connection, has its own DI module in the unit that
  owns it (`…data.exposed.di.ExposedModule` exposing `databaseFlow`). Several DI modules in one unit are
  normal, and existing ones are never merged.
- A DI module that starts or stops something exposes `val lifecycle: Lifecycle` (AstraLibs
  `Lifecycle.Lambda`), and a parent module or `RootModule` collects the `lifecycle`s of its children: its own
  `lifecycle` calls theirs in order. A DI module never replaces this with its own
  `enable()`/`reload()`/`disable()` functions, and never moves a child's work into its own lambda.
- `RootModule` only builds the root DI modules and lists their `lifecycle`s; it constructs no service itself.
- A DI module is `internal` unless another build unit constructs it.
- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons.
- These rules apply to the DI modules a task creates. Existing wiring that breaks them stays as it is until
  the user asks to change it.
