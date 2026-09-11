## Dependency Injection

Manual constructor injection — no Koin, Dagger, or other DI frameworks.

A module is a Kotlin `class` (e.g. `DomainModule`) that declares its services as properties, constructs
their concrete instances, and receives other modules as constructor parameters. Use a class by default.
Make a module an `interface` with a separate implementation only when it has to be extended or split into
api/impl.

`RootModule` in each `instances:<name>` is the composition root: it instantiates all modules in dependency order using `lazy {}` where construction must be deferred.

- Pass the whole module as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons.
