## Dependency Injection

Manual constructor injection — no Koin, Dagger, or other DI frameworks.

A DI module is a Kotlin `class` (e.g. `LinkModule`) that declares its services as properties, constructs
their concrete instances, and receives other DI modules as constructor parameters. Use a class by default.
Make a DI module an `interface` with a separate implementation only when it has to be extended or split into
api/impl. "DI module" names this class only; a Gradle module is a build unit.

`RootModule` is the composition root: the one DI module per application that constructs all the others in
dependency order, using `lazy {}` where construction must be deferred. It lives in `di/RootModule.kt` of the
unit that starts the application (`instances:<name>`, the plugin unit), next to the entry point that creates it.

- Every DI module lives in the `di/` package of the concept it wires: `…link.di.LinkModule`,
  `…link.player.di.LinkDatabaseModule`. It is `internal` unless another build unit constructs it.
- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons.
