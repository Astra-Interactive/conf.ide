## Package layout

**Before the first new file of a task, load the `package-layout` skill, record `BASE=$(git rev-parse HEAD)` and
print the planned tree.** The skill holds the procedure, the decision tests, the checklist and the worked
examples. This rule holds what the finished tree must look like; `arch-package.kt.md` and `arch-package.rs.md`
add the language mechanics; `arch-domain.md` holds the domain building blocks; `arch-context.md` holds what
crosses between contexts.

Terms used below:

- **unit**: a build unit, a Gradle module or a Cargo crate;
- **capability**: a cohesive piece of the system with one reason to change; a capability is either a
  context or a module of a context;
- **context**: a bounded context, the top-level capability: its own vocabulary, its own data, something that
  could become a unit or a service of its own;
- **module**: a capability inside a context (an aggregate, a sub-feature);
- **role**: a package named for what the platform or the context does with its files (`command`, `model`, `data`);
- **entry point**: a class the platform calls (a command, a listener, a route, a screen, a scheduled task);
- **core**: the shared platform unit of a project; **kernel**: its shared domain unit.

### Units

1. A project has four kinds of unit:
   - a **context**, named for its capability (`jail`, `claim`);
   - an **entry point** (`instances/bukkit`, `androidApp`): the platform main class and the composition root
     (`RootModule`), nothing else. Nothing depends on it. An application may have several, one per platform
     or a debug instance;
   - a **shared unit**: `core` for platform infrastructure that knows no domain word; a domain kernel for the
     typed identifiers and generic value objects two or more contexts share, named for what it holds, never
     `common` or `shared`; a `<context>/contract` unit for the wire types a server and its client share.
     Nothing enters `core` or the kernel before its second consumer, and business logic never does;
   - a **tooling unit** that holds no product code: `build-logic` with the convention plugins, an `xtask`
     crate, a `<feature>/fake` unit for the shared fakes of a Multiplatform context.
   A published library (AstraLibs) is a dependency of a project, not one of its units.
2. A context is its own unit whenever the project has more than one context; a single-context project is one
   unit. A module of a context is never a unit. Rust cuts differently because its modules encapsulate: see the
   Rust companion. In a published library, a capability lives as a package inside the unit that matches its
   platform scope (`core`, `core-bukkit`) and becomes a unit of its own only when it brings dependencies the
   other capabilities must not inherit.
3. A context splits into `<context>/api` and `<context>/impl` units on two triggers only: another context
   depends on it, or it has two or more platform units. The dependency itself is the trigger: a context that
   another context needs is split before the dependency is declared, so a consumer always depends on an `api`
   unit. Otherwise a context is one unit whose root package is its public surface. `api` and `impl` are unit
   names and never package names.
4. Platform code is a unit `<context>/<platform>` (`claims/bukkit`) when the platforms are separate Gradle
   JVM builds, and a source set of the context's unit when the build is Kotlin Multiplatform. A platform unit
   or source set holds only the platform's words and no domain logic.
5. A unit's directory never holds another unit: when a context is split, or has a `contract` unit, its
   directory is a container with no build file and no sources (`dictionary/contract`, `dictionary/impl`).
6. Every unit carries a `README.md` of one sentence stating its responsibility. A sentence that does not fit is
   the signal to split the unit.
7. A small platform piece that does not deserve a unit of its own lives in `core` as a capability-named
   package (`core/coroutine`), never as a tiny unit.

### The top level of a unit

What sits directly under a unit's root package depends on the kind of unit, and a layer or kind name
(`domain`, `data`, `presentation`, `service`, `util`, `common`, `api`, `impl`) is never the first level of a
unit that holds several capabilities:

- a **context unit** (`impl` or unsplit): the unit *is* the context, so its root package holds the use cases
  and its roles sit directly under it (`jail/command`, `jail/model`, `jail/data`);
- an **`api` unit**: the `<Context>Api` contract at the root, `model/` for the types in its signatures,
  `stub/` under the contract;
- an **entry-point unit**: the main class and `di/`;
- **`core`, the kernel, a library unit**: capability-named packages (`coroutine`, `encoding`, `economy`),
  each with its roles inside; never a layer or kind name at that level.

### Capabilities

- A capability is a cohesive piece with one reason to change. It is a **context** when all three hold: its
  data, if any, is its own; it has words of its own; a typical change to it stays inside it. Otherwise it is a
  **module** of the context that owns the data it touches. The kinds below are examples, not a closed list,
  and the call is the author's: what the user does (`sethome`, `jail`); a reaction to platform events with no
  command (`autocrop`, `moneydrop`); an integration with an external system; a technical capability a library
  exports (`encoding`, `localization`); a platform adapter of a context (`claims/bukkit`).
- A capability is never a screen and never a single entity. Operations that write the same data belong
  together: `Jail`, `JailInmate` and `JailLocation` are one context, not three.
- Naming: the capability in the project's own words, singular, lowercase, one segment (`sethome`, `claim`).
  An entity name is allowed only when the capability and the entity coincide (`jail`).
- A context owns its tables, files and krates. Another context reaches that data only through the owner's
  contract. The connection, the serialization and the migrations are shared and live in `core`.
- Merge two contexts that constantly need each other's data. Check a boundary with the change test: a typical
  change touches one context. About fifteen entities in one context is a smell that triggers a review.
- The building blocks of `arch-domain.md` (entity, value object, aggregate, use case, domain event, factory)
  apply only in a context that has business rules. A CRUD context is model, storage and command, with nothing
  between them; the rules on the model's imports, on one model per context and on the repository apply to it
  all the same.

### Inside a context

The context root holds the use cases, verb-named classes such as `JailPlayer` and `FreeInmate`; the
`<Context>Api` contract when the context publishes one; and the one class that implements that contract,
`Default<Context>Api`, which is the façade over the use cases. Nothing else is loose at the root. Every other
file is in a role package from the menu below. A role package exists only when it has a file; there is no
mandatory set and no empty folder; a one-file package is normal; there is no flat stage, roles are used from
the first file.

| Role | Holds |
|---|---|
| `command`, `event`, `route`, `composable`, `viewmodel` | entry points, one package per mechanism that invokes them: the command framework, the event bus (listeners and the platform event types that carry the context's events), the HTTP router, the UI |
| `service` | a component the platform runs on its own lifecycle: an Android or Bukkit service, an `IntervalService` task |
| `job` | a unit of work a scheduler framework runs on its schedule (WorkManager, a cron library) |
| `model` | the context's own types, its errors (one sealed family per file), its results and read projections, its events |
| `data` | the repository contracts; beneath them one package per technology (`data/exposed`, `data/krate`, `data/file`, `data/memory`), each holding that technology's implementation and, when it has many files, its `table`, `entity` and `model` packages; `data/model` for types the technologies share |
| `integration` | contracts for what the context needs from other contexts and external systems; beneath them one package per system (`integration/vault`, `integration/luckperms`) holding both what the context calls on that system and the provider the system calls on the context |
| `mapping` | conversions between two representations shared by more than one file: the anti-corruption layer |
| `util` | extension functions and helpers that are not part of a model, by the author's judgment (see Files) |
| `di` | exactly one DI module that constructs the capability's graph (see the DI rule) |
| `<module>` | a module of the context: a sub-package with the same roles inside, created only when it has three or more files or storage of its own; below that its files sit in the context's role packages; two levels at most, redraw the context rather than nest deeper |

Never a package name, at any level: `domain`, `application`, `infrastructure`, `presentation`, `ui`,
`controller`, `entrypoint`, `api`, `impl`, `internal`, `usecase`, `repository`, `valueobject`, `aggregate`,
`factory`, `exception`, `dto`, `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`,
`in`, `out`, `spi`, `inbound`, `outbound`, `validation`. `entity` and `table` are allowed only inside a
technology package, because they are that technology's words. When no role fits a file, it goes to the
closest role on the menu and the final message reports the gap; the menu is not extended by a task. Every
package name is singular; the only exception is a concept that is inherently plural (`news`).

### Contracts and implementations

- An interface exists on four triggers and no other: another unit calls it; two or more implementations exist
  or one is known to come; an inner part declares what it needs from an outer one; a test must replace it with
  a fake, which is allowed only for a contract over I/O or the platform. Pure logic gets no interface. An
  entity gets no interface. A use case gets no interface.
- The contract sits at the level of the role it abstracts; its implementation sits one level down, in a
  package named by the library or technology it uses (`exposed`, `krate`, `ktor`, `room`), or by the kind word
  when the technology has no name of its own (`file`, `memory`). `database`, `network`, `local` and `remote`
  are not technology names. Sub-packages never introduce new concepts, only more detail.

  ```
  jail/data/JailRepository.kt                   the contract: what jail needs from storage
  jail/data/file/FileJailRepository.kt          the implementation, named by what it uses
  jail/data/memory/InMemoryJailRepository.kt    production code, usable by tests and demos
  jail/data/memory/CachedJailRepository.kt      a cache is another implementation that wraps one
  ```

- The interface takes the plain name. The implementation is named by its technology or variant
  (`FileJailRepository`, `ExposedMoneyDropRepository`, `InMemoryJailRepository`, `FakeJailRepository`);
  `Default…` only when nothing better fits, which is the case of the one implementation of a `<Context>Api`.
  `Impl`, the `I` prefix and the `Interface` suffix are forbidden.
- A context publishes one interface named `<Context>Api` by default, at its root. It splits into several
  only when a second consumer needs a different slice or the interface forces stubs to implement methods they
  do not use. Its signatures use the context's own model types, placed with the contract; an identifier is
  preferred over a whole object where the consumer only refers to something; an outward copy of a type exists
  only when the public surface must hide fields.
- A stub or preview implementation that other units need lives in the `api` unit, one level under its
  contract: `api/stub/StubMonetizationApi`.
- Dependency direction inside a context: `model` depends on nothing in the context; contracts (`data`,
  `integration`) depend on `model`; use cases depend on contracts and `model`; technology packages and
  `mapping` depend on the contracts above them and `model`; entry points, and the providers in
  `integration/<system>` that an external system calls, depend on use cases, contracts and `model`; nothing
  depends on an entry point; `di` depends on everything and nothing depends on it. A use case and a contract
  import no platform or framework type and reach the server through the library's abstractions or the
  context's own `integration` contract; entry points and technology packages may import the platform freely.
- No pass-through: an entry point may call a contract or storage directly. A use case exists only when the
  flow has more than one step: it reads from a contract, applies a model rule to the result and acts on the
  outcome, or it combines two or more contracts. A single contract call with no branch is not a use case. A
  use case is one action per class with one public entry, and it never calls another use case.

### Files

- A file holds one type family and is named after its primary type, or after its contents in UpperCamelCase
  when it has none; never `Util`. A family is a sealed type with all its variants, a class with the types only
  it uses, or a contract with its small related types. A file is split only above about 400 lines, by moving a
  whole group into a second file of the same package.
- A data class that is a property type of exactly one class is nested in it, however many files read it. A
  type that is a property of two or more classes, or is returned to another class, is top-level in `model`.
- Errors are one sealed family per file in `model`, next to the types they concern; a technology-specific
  error lives in its technology package; in a library, the exceptions that are part of a contract sit in the
  contract's package. There is no `exception` package, and an old one receives no new file.
- Wire types: when the server and its client are in one repository, the request and response types belong to
  the `<context>/contract` unit and both the route and the client use them. When only one side is yours, a
  route's types live in `route/` with the route, and a remote client's in `data/<technology>`, in a `model`
  sub-package when there are many. There is no `dto` package; "DTO" may appear in a type name.
- Extensions follow the Kotlin convention by default: an extension for all clients of a type lives in the
  type's file, one for a single client next to that client. `util/<Subject>Ext.kt` is the allowed alternative
  when the author judges the extensions are not part of the type. There is no third option. Helpers are
  top-level functions, never an `object` used as a namespace.
- A domain type carries no kind suffix: `Jail`, not `JailModel` or `JailEntity`. The technology representation
  carries the technology word: `MoneyDropLocationTable`, `JailRow`.

### Existing code

- Never move, rename or delete a file that existed before the task, unless the user asks. An old unit or
  package in the wrong shape (`claims/api` holding an implementation, a top-level `util`,
  `autocrop/presentation`) stays as it is.
- Edit an old file only where the new code plugs in: a new call, a new branch, a new constructor argument, a
  new line of wiring, a new variant or property of an old type. Leave every other old line as it is.
- New files follow this rule even next to old packages named otherwise: a new listener in `autocrop` goes to
  `event/`, not to the old `presentation/`; a new error goes to `model/`, not to an old `exception/`. A new
  role package next to old loose files is correct.
- The final message lists the old files the rule would move, and where.

### Enforcement

Every line of this rule that a tool can check is meant to be checked in the build and not trusted to prose:
the direction between roles, the package names, the naming of implementations, the imports allowed in
`model`, use cases and contracts, the dependencies of an `api` unit. The skill names the checker; until it
exists, the skill's checklist is answered by hand and the final message says so.

**Load the `package-layout` skill before the first new file of a task.**
