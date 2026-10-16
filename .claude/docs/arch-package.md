## Package layout

**Before the first new file of a task, load the `package-layout` skill, record `BASE=$(git rev-parse HEAD)` and
print the planned tree.** The skill holds the procedure, the checklist and the worked examples. This rule holds
what the finished tree must look like; `arch-package.kt.md` and `arch-package.rs.md` add the language
mechanics; `arch-domain.md` holds the domain building blocks; `arch-context.md` holds what crosses between
contexts.

Terms used below:

- **unit**: a build unit, a Gradle module or a Cargo crate;
- **context**: a bounded context, the top-level unit of code: its own vocabulary, its own data, something that
  could become a unit or a service of its own;
- **module**: a concept inside a context (an aggregate, a sub-feature);
- **role**: a package named for what the platform or the context does with its files (`command`, `model`, `data`);
- **entry point**: a class the platform calls (a command, a listener, a route, a screen, a scheduled task);
- **core**: the shared platform unit of a project; **kernel**: its shared domain unit.

### Units

1. A project has three kinds of unit:
   - a **context**, named for its capability (`jail`, `claim`, `encoding`);
   - an **entry point** (`instances/bukkit`, `androidApp`): the platform main class and the composition root,
     nothing else. Nothing depends on it. An application may have several, one per platform or a debug instance;
   - a **shared unit**: `core` for platform infrastructure that knows no domain word; a domain kernel for the
     typed identifiers and generic value objects two or more contexts share, named for what it holds, never
     `common` or `shared`; a `<context>/contract` unit for the wire types a server and its client share.
     Nothing enters a shared unit before its second consumer, and business logic never does. A published library
     (AstraLibs) is a dependency of a project, not one of its shared units.
2. A context is its own unit whenever the project has more than one context; a single-context project is one
   unit. A module of a context is never a unit. Rust cuts differently because its modules encapsulate: see the
   Rust companion.
3. A context splits into `<context>/api` and `<context>/impl` units on two triggers only: another context
   depends on it, or it has two or more platform units. Otherwise it is one unit whose root package is its
   public surface. `api` and `impl` are unit names and never package names. Platform code is a unit
   `<context>/<platform>` (`claims/bukkit`) when the platforms are separate Gradle JVM builds, and a source set
   of the context's unit when the build is Kotlin Multiplatform.
4. A unit's directory never holds another unit: a split context's directory is a container with no build file
   and no sources.
5. Every unit carries a `README.md` of one sentence stating its responsibility. A sentence that does not fit is
   the signal to split the unit.
6. A small platform piece that does not deserve a unit of its own lives in `core` as a capability-named
   package (`core/coroutine`), never as a tiny unit.

### The top level of a unit

The first level under a unit's root package is capabilities (`jail`, `encoding`, `economy`). A layer or kind
name never appears there: no `domain`, `data`, `presentation`, `api`, `impl`, `service`, `util`, `common` at the
top of any unit, in plugins, apps and libraries alike. A context unit's root package *is* the context, so its
roles sit directly under it.

### Contexts

- A context is independent: its data, if it has any, is its own; it has words of its own; a typical change
  to it stays inside it; it depends on other contexts only through their public surface.
- Kinds of module, as examples and not as a closed list (the call is the author's): what the user does
  (`sethome`, `jail`); a reaction to platform events with no command (`autocrop`, `moneydrop`); an integration
  with an external system; a technical capability a library exports (`encoding`, `localization`); a platform
  adapter of a context (`claims/bukkit`); the entry point.
- A module is never a screen and never a single entity. Operations that write the same data belong to one
  module: `Jail`, `JailInmate` and `JailLocation` are one context, not three.
- Naming: the capability in the project's own words, singular, lowercase, one segment (`sethome`, `claim`).
  An entity name is allowed only when the capability and the entity coincide (`jail`).
- A context owns its tables, files and krates. Another context reaches that data only through the owner's
  contract. The connection, the serialization and the migrations are shared and live in `core`.
- Merge two contexts that constantly need each other's data. Check a boundary with the change test: a typical
  change touches one context. About fifteen entities in one context is a smell that triggers a review.
- The domain building blocks of `arch-domain.md` apply only in a context that has business rules. A CRUD
  context is model, storage and command, with nothing between them.

### Inside a context

The context root holds the use cases, verb-named classes such as `JailPlayer` and `FreeInmate`, and nothing
else loose. Every other file is in a role package from the menu below. A role package exists only when it has
a file; there is no mandatory set and no empty folder; a one-file package is normal; there is no flat stage,
roles are used from the first file.

| Role | Holds |
|---|---|
| `command`, `event`, `service`, `route`, `job`, `composable`, `viewmodel` | entry points, one package per mechanism that invokes them: the command framework, the event bus, the scheduler or platform lifecycle, the HTTP router, the UI |
| `model` | the context's own types, its errors (one sealed family per file), its results and read projections, its events |
| `data` | the repository contracts; beneath them one package per technology (`data/exposed`, `data/krate`, `data/file`, `data/memory`), each holding that technology's implementation and, when it has many files, its `table`, `entity` and `model` packages; `data/model` for types the technologies share |
| `integration` | contracts for what the context needs from other contexts and external systems; beneath them one package per system (`integration/vault`, `integration/luckperms`) holding both what the context calls on that system and what it exposes to it |
| `mapping` | conversions between two representations shared by more than one file: the anti-corruption layer |
| `util` | extension functions and helpers that are not part of a model, by the author's judgment (see Files) |
| `di` | exactly one DI module, the context's composition root (see the DI rule) |
| `<module>` | a module of the context: a sub-package with the same roles inside, created when it has three or more files or storage of its own; two levels at most, redraw the context rather than nest deeper |

Never a package name, at any level: `domain`, `application`, `infrastructure`, `presentation`, `ui`,
`controller`, `entrypoint`, `api`, `impl`, `internal`, `usecase`, `repository`, `valueobject`, `aggregate`,
`factory`, `exception`, `dto`, `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`,
`in`, `out`, `spi`, `inbound`, `outbound`, `validation`. `entity` and `table` are allowed only inside a
technology package, because they are that technology's words. `service` means only a component the platform
runs on its own schedule or lifecycle. Every package name is singular; the only exception is a concept that is
inherently plural (`news`).

### Contracts and implementations

- An interface exists on four triggers and no other: another unit calls it; two or more implementations exist
  or one is known to come; an inner part declares what it needs from an outer one; a test must replace it with
  a fake, which is allowed only for a contract over I/O or the platform. Pure logic gets no interface. An
  entity gets no interface. A use case gets no interface.
- The contract sits at the level of the role it abstracts; its implementation sits one level down, in a
  package named by the library or technology it uses (`exposed`, `krate`, `ktor`, `room`), or by the kind word
  when the technology has no name of its own (`file`, `memory`). Sub-packages never introduce new concepts,
  only more detail.

  ```
  jail/data/JailRepository.kt                   the contract: what jail needs from storage
  jail/data/file/FileJailRepository.kt          the implementation, named by what it uses
  jail/data/memory/InMemoryJailRepository.kt    production code, usable by tests and demos
  ```

- The interface takes the plain name. The implementation is named by its technology or variant
  (`FileJailRepository`, `ExposedMoneyDropDao`, `InMemoryJailRepository`, `FakeJailRepository`); `Default…`
  only when nothing better fits. `Impl`, the `I` prefix and the `Interface` suffix are forbidden.
- A context publishes one interface named `<Context>Api` by default. It splits into several only when a
  second consumer needs a different slice or the interface forces stubs to implement methods they do not use.
  Its signatures use the context's own model types, placed with the contract; an identifier is preferred over
  a whole object where the consumer only refers to something; an outward copy of a type exists only when the
  public surface must hide fields.
- A stub or preview implementation that other units need lives in the `api` unit, one level under its
  contract: `api/stub/StubMonetizationApi`.
- Dependency direction inside a context: `model` depends on nothing in the context; use cases and contracts
  depend on `model`; technology packages and entry points depend on contracts and `model`; nothing depends on
  an entry point; `di` depends on everything and nothing depends on it. A use case and a contract import no
  platform or framework type and reach the server through the library's abstractions or the context's own
  `integration` contract; entry points and technology packages may import the platform freely.
- No pass-through: an entry point may call a contract or storage directly. A use case exists only when it
  decides something or combines two or more contracts; it is one action per class with one public entry, and
  it never calls another use case.

### Files

- A file holds one type family and is named after its primary type, or after its contents in UpperCamelCase
  when it has none; never `Util`. A family is a sealed type with all its variants, a class with the types only
  it uses, or a contract with its small related types. A file is split only above about 400 lines, by moving a
  whole group into a second file of the same package.
- A data class that is a property type of exactly one class is nested in it, however many files read it. A
  type that is a property of two or more classes, or is returned to another class, is top-level in `model`.
- Errors are one sealed family per file in `model`, next to the types they concern; a technology-specific
  error lives in its technology package; in a library, the exceptions that are part of a contract sit in the
  contract's package. There is no `exception` package.
- Wire types live with the route that uses them, or in `data/<technology>` for a remote client, in a `model`
  sub-package when there are many. There is no `dto` package; "DTO" may appear in a type name.
- Extensions follow the Kotlin convention by default: an extension for all clients of a type lives in the
  type's file, one for a single client next to that client. `util/<Subject>Ext.kt` is the allowed alternative
  when the author judges the extensions are not part of the type. There is no third option. Helpers are
  top-level functions, never an `object` used as a namespace.
- A domain type carries no kind suffix: `Jail`, not `JailModel` or `JailEntity`. The technology representation
  carries the technology word: `MoneyDropLocationTable`, `JailRow`.

### Existing code

- Never move, rename or delete a file that existed before the task, unless the user asks. An old unit or
  package in the wrong shape (`claims/api` holding an implementation, a top-level `util`) stays as it is.
- Edit an old file only where the new code plugs in: a new call, a new branch, a new constructor argument, a
  new line of wiring, a new variant or property of an old type. Leave every other old line as it is.
- New files follow this rule inside old packages too: a new role package next to old loose files is correct.
  When the unit already names a role with another word, new files of that role use that word.
- The final message lists the old files the rule would move, and where.

### Enforcement

Every line of this rule that a tool can check is checked in the build and not trusted to prose: the direction
between roles, the package names, the naming of implementations, the imports allowed in `model`, use cases and
contracts, the dependencies of an `api` unit. The skill names the checker.

**Load the `package-layout` skill before the first new file of a task.**
