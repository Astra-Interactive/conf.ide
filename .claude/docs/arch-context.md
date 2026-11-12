## Boundaries between units

This rule says how units relate: what one may depend on, what crosses between them, what is shared, and what
enforces it. The package-layout rule defines the units; the domain rule defines what is inside them.

### The dependency graph

- The units' production dependencies form an acyclic graph. An edge is one of these kinds: a use of an `api`
  unit or of the storage contracts unit (its contracts, models, model rules in `util`, use cases, its `stub`
  implementations and, in a plugin's `api` unit or the storage contracts unit, its `memory` implementations); a
  subscription to its events; a use of `core` (its models, helpers and scopes); a use of a
  context's `contract` unit; a unit implementing a contract of a unit it may depend on (a technology unit the
  storage contracts or its own `api`, a platform unit its own `api`, a `<feature>/fake` the `api` it fakes); a DI module taking
  the DI module of a unit it may depend on; the entry-point unit building the product units' DI modules.
  A state holder's public interface in an `api` unit is a contract, even in `component` or `viewmodel`.
  Test source sets (in Rust, a crate's `test/` tree) may also use exported fake implementations
  (`arch-package.kt.md`, `arch-package.rs.md`, Tests).
  Nothing else crosses: no other implementation is called across units, no table, and no platform type into
  a platform-free unit (a plugin's `api` unit, `core/api`, the storage contracts unit). An app's UI `api`
  may expose its state holder's UI framework and the Compose model types allowed by `compose.kt.md`;
  this does not permit unrelated platform, ORM or network types in its contracts or models.
- A sub-context depends on another through that one's `api` unit (`command` → `gui/api` to call
  `AddRatingUseCase`). Only the entry-point unit depends on a feature's platform unit (`gui/bukkit`), and
  nothing depends on the entry-point unit. In an app, only the entry-point unit depends on an `impl` unit, and a
  feature's UI unit (`impl-ui`) on the `impl` unit beside it.
- The owner and production consumers determine a use case's unit (`arch-package.md`, Units 4–6).
  A dependency permitted by this table does not by itself justify putting code in an API unit.
- Storage is reached through its contracts unit (`data/dao`). Only the technology unit (`data/exposed`) and
  the entry-point unit depend on the technology.
- A sub-context publishes general events, shaped for no single consumer.

### What crosses

- A contract's signatures use the provider's own model types, placed with the contract. An identifier is
  preferred over a whole object where the consumer only refers to something.
- A sub-context never reads another's tables or files; it calls the storage contract.
- A server and its client share wire types through a `<context>/contract` unit of serializable types and route
  constants; neither side's model crosses the wire.

### The anti-corruption layer

- When a provider's model is not yours to control (an external library, a platform API, a remote system, a
  third-party plugin such as PlaceholderAPI, Vault, LuckPerms), the integration with it is its own sub-context
  (`integration-papi`) or a concept inside one. It declares in its own words what it needs, translates at its
  edge, and holds both what it calls on that system and what it exposes to it (`RatingPlaceholderExpansion`).
- A framework type that leaks into a contract (`Page`, `Pageable`, a plugin's `Location`) is the violation to
  look for: it is replaced by a model type and mapped in the implementation. A state holder's UI contract
  is the exception: it may use its own UI framework (`ComponentContext`, `Value`, `Render()`), as
  `arch-package.kt.md` allows; a UI unit's models may carry Compose types as `compose.kt.md` allows.

### `core`

- `core` is the project's common unit for what is not worth a unit of its own: config, translation and
  permission models, shared functions, shared coroutine scopes (Rust: a `TaskScope`, `async.rs.md`), generic
  classes that units of two sub-contexts need (`core/cache/cache4k/<Class>`, moved there once a unit of a
  second sub-context needs it), small platform pieces as packages (`core/coroutine`). It has the same concept →
  kind shape as any unit. It may be split by platform (`core/api`, `core/bukkit`) and, in an app with Compose,
  into a design-system unit (`core/ui`).
- A platform unit of `core` may keep implementations directly in concept packages, as described by the
  package-layout implementation exception. This does not change the dependency tables below: `core/bukkit`
  still depends only on `core/api`, and its explicit kind packages keep their import restrictions.
- `core` holds no use case and no repository, and depends on no feature unit. Nothing enters it before its
  second consumer.
- A published library (AstraLibs) is a dependency, not the `core` of any project.

### Direction and enforcement

| Inside a unit | may depend on |
|---|---|
| `model` | other `model` packages: of a higher level or of another concept of the unit |
| `api` (contracts) | `model`; runtime contract parameters of the `Factory` exception below (nested in Kotlin; a `<Type>Factory` trait in the contract's file in Rust) |
| `usecase` | `api`, `model`, `util` |
| implementations (technology packages and units), `stub` | `api` (the contract they implement and the contracts they call), `model`, `util`, and what sits in their own technology package or unit (`table`, `entity`, `database`, a helper class beside them); a router's implementation also the UI kinds it opens |
| `fake` (test implementations) | `api` (the contract it replaces), `model`, `util` |
| entry-point and UI kinds, the project's own words for them included (`command`, `event`, `gui`, `slot`, `component`, `context`, `route`, `composable` and its sub-packages, `viewmodel`, …), and `warmup`, `migration`, `error` | `usecase`, `api`, `model`, `util`; `theme` for the Compose kinds; the other UI kinds of the same unit, with no cycle between them: a whole depends on its parts (a screen on its components and layouts, a menu on its slots), and a whole is used only by what hosts or opens it (a parent composable, a component's `Render()`, a router's implementation) |
| `theme` (Compose) | `model`, `theme` (including the theme object's access to its `CompositionLocal`s) |
| `util` | `api`, `model`, `util`; `theme` in a Compose unit; `table`, `entity`, `database` in a unit that is wholly one technology |
| `di` | everything |
| classes the platform constructs at the root of the entry-point unit | `di` to create and use the composition root; the UI kinds they host |

A row names kinds, not concepts, except for the platform-constructed root classes. A kind may depend on the
listed kinds of any concept and any higher level of
its unit, with no cycle between packages (`jail/model/JailInmate` on `PlayerId` in the unit's `model`).
The `util` and `theme` rows allow references within the same kind; they do not grant that permission to
every kind. A use case still never calls another use case. Only `di` and the platform-constructed root
classes may depend on `di`; ordinary entry-point kinds do not gain that access.

Framework registration interfaces described in `arch-package.md` may be used by entry mechanisms,
implementations and DI, including through a permitted dependency on mixed `core`. This allows a reference
to the registration interface, not arbitrary dependencies between entry-point kinds. Domain models,
contracts and use cases may not depend on these interfaces. Unit dependency permissions remain unchanged.

The runtime construction exception in `arch-domain.md`, Factory, permits a nested `fun interface Factory`
in an `api` contract (in Rust, a `<Type>Factory` trait in the contract's file, `arch-domain.rs.md`) to
reference another contract solely as a runtime parameter of its creation function.
The factory returns the enclosing contract, and a DI module implements it. This exception adds no permission
for ordinary contract operations, implementation types or cycles.

| Between units | may depend on |
|---|---|
| entry-point unit | every product unit; no `<feature>/fake` in production source sets (in Rust, no `fake` feature in `[dependencies]`) |
| a platform unit (`gui/bukkit`) | its own `api`, other `api` units, `core` and its platform unit (`core/bukkit`), the storage contracts unit |
| an unsplit sub-context (`event-bukkit`) | `api` units, `core` and its platform unit, the storage contracts unit |
| an `api` unit | other `api` units, the platform-free `core` (`core/api`), the storage contracts unit |
| an `impl` unit (app) | its own `api`, other `api` units, `core` |
| an `impl-ui` unit (app) | its own `api`, other `api` units, `core` and its design-system unit, the `impl` unit beside it; another feature's `impl-ui` when it composes them (`composition = "host"`) |
| a technology unit (`data/exposed`, `discord-ai/ktor`) | its own `api` unit (both unit paths have the same immediate parent), the storage contracts unit, platform-free `core` |
| the storage contracts unit (`data/dao`) | `core` |
| `contract` | nothing of the project |
| `core` (`core/api`) | nothing of the project |
| the platform unit of `core` (`core/bukkit`) | `core/api` |
| the design-system unit of `core` (`core/ui`) | `core/api` |
| `<feature>/fake` | the `api` it fakes |
| a Rust `proc-macro` crate | nothing of the project; every production unit may depend on it, whatever its own row says, since the crates that expand its macros need it in their normal build |
| a Rust `tooling` crate (`xtask`) | nothing of the project; nothing depends on it, as on Kotlin's `build-logic` |
| a unit that serves or calls a context's routes | its row above, plus that context's `contract` unit |
| a test source set (in Rust, a crate's `test/` tree with its `[dev-dependencies]`) | its unit's row above, plus shared fakes from `<feature>/fake` or `testFixtures` (in Rust, another crate's `fixture/` tree through its `fake` feature); these additions are test-only dependencies |

A technology unit's own `api` allowance does not permit dependencies on another sub-context's `api`,
including a nested unit with a different immediate parent. The resolved unit roles determine this allowance,
including when a declared role (a convention plugin, a Rust manifest's `role`) overrides the detected one or
the API unit has a name other than `api`.

No cycles between production units or between packages. Test-only dependencies do not become production
edges; each compilation's dependency graph must remain acyclic. Only test source sets consume a
`<feature>/fake` unit or a Rust `fake` feature. These two tables are the whole list.

A checker knows the fixed kinds by name: `api`, `model`, `usecase`, `util`, `di`, `theme`, `stub`, `warmup`,
`migration`, `error`, `table`, `entity`, `database`, `composable` (the one kind whose sub-packages are kinds
too: `screen`, `component`, `layout`, a project's own word) and `fake` in a test tree (Kotlin test or
`testFixtures`; a Rust crate's `test/` or `fixture/`), or in `commonMain` of a dedicated `<feature>/fake`
unit. A technology package is named after a library the unit depends on (read from its build file), or
`file`, `memory` (Rust also `system`). In a
unit that is wholly one technology, a concept package holds its implementations directly
(`router/BukkitGuiRouter`), and the root package of the entry-point unit holds the classes the platform
constructs. An entry-point or UI kind is a word listed in the checker's config, the project's own words
(`command`, `gui`, `slot`, `expansion`); any other package that holds files is flagged. A unit's type comes
from its build file: in Kotlin, the convention plugin it applies (one per unit type, `arch-package.kt.md`),
which the checker's config maps to a row of the table above, and a unit without such a plugin is checked by
hand; in Rust, the `role` its manifest declares, else the role its path and targets give (`arch-package.rs.md`).

Every row of these tables, the package names and the naming of implementations are meant to be checked by a
tool in the build; the platform and framework imports of `model`, `api` and `usecase` are the reviewer's call.
Run the checks configured in the project and review any uncovered requirements with the skill's checklist.
Dependency-direction checks do not establish whether a declaration needs to cross a unit boundary.
