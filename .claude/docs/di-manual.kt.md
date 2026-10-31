## Dependency Injection

Manual constructor injection — no Koin, Dagger, or other DI frameworks.

A DI module is a Kotlin `class` (e.g. `LinkModule`) that declares its services as properties, constructs their
concrete instances, and receives other DI modules as constructor parameters. Use a class by default. Make a DI
module an `interface` with a separate implementation only on a trigger of the package-layout rule (Contracts
and implementations). "DI module" names this class only; a Gradle module is a build unit.

`RootModule` is the composition root: the one DI module per application that builds the root DI modules in
dependency order, using `lazy {}` where construction must be deferred. A project that already names its
composition root otherwise keeps that name, and the rules about `RootModule` apply to it. It lives in the `di`
package of the entry-point unit (`instances/<name>`), whose root holds the class that creates it.

- References between DI modules form an acyclic graph that follows the unit dependencies; several modules
  may receive the same dependency instance. Lifecycle ownership forms a tree: a module's children are only
  the DI modules it directly creates. Each unit that assembles dependencies has its own DI module in the `di/`
  package of the level it wires (`…command.di.CommandsModule`, `…gui.api.di.GuiModule`). A
  resource with its own lifecycle, such as a database connection, has its own DI module in the unit that
  owns it (`…data.exposed.di.ExposedModule` exposing `databaseFlow`). Several DI modules in one unit are
  normal, and existing ones are never merged.
- Declaring a constructible class or allocating its own state is not dependency assembly. Tests may
  construct fakes directly; a unit of fake declarations alone needs no DI module.
- A DI module that starts or stops something exposes `val lifecycle: Lifecycle` (AstraLibs
  `Lifecycle.Lambda`), and collects the `lifecycle`s only of the DI modules it directly creates: its own
  `lifecycle` calls theirs in order. It never starts, reloads or stops a DI module received as a dependency.
  `RootModule` follows the same ownership rule. A DI module never replaces `Lifecycle` with its own
  `enable()`/`reload()`/`disable()` functions, and never moves a child's work into its own lambda.
- `RootModule` only builds the root DI modules and lists their `lifecycle`s; it constructs no service itself.
- A DI module is `internal` unless another build unit constructs it.
- Pass the whole module as a dependency, not individual services extracted from it. When the providing DI
  module sits in a unit the consumer may not depend on (`data/exposed` for `gui/api`), the consumer's DI
  module takes the contract it needs as a constructor parameter
  (`RatingPlayersModule(ratedUsersCache: RatedUsersCache)`).
- A task that seeds or migrates a resource (`warmup`, `migration`) is built by the DI module of that resource
  and started by its `lifecycle` (`RatingStorageModule` starts `RatingCacheWarmUp` in `onEnable`).
- Never use a service locator or global singletons.
- These rules apply to the DI modules a task creates. Existing wiring that breaks them stays as it is until
  the user asks to change it.
