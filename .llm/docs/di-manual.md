## Dependency Injection

Manual constructor injection — no Koin, Dagger, or other DI frameworks.

Each module is a Kotlin `class` (e.g. `DomainModule`) that declares its services as properties. A class implements it by constructing concrete instances, receiving other module interfaces as constructor parameters.

`RootModule` in each `instances:<name>` is the composition root: it instantiates all modules in dependency order using `lazy {}` where construction must be deferred.

- Pass the whole module interface as a dependency, not individual services extracted from it.
- Never use a service locator or global singletons.
