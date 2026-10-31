## Boundaries between units

This rule says how units relate: what one may depend on, what crosses between them, what is shared, and what
enforces it. The package-layout rule defines the units; the domain rule defines what is inside them.

### The dependency graph

- The units' production dependencies form an acyclic graph. An edge is one of these kinds: a use of an `api`
  unit or of the storage contracts unit (its contracts, models, model rules in `util`, use cases, and its `stub` and `memory`
  implementations); a subscription to its events; a use of `core` (its models, helpers and scopes); a use of a
  context's `contract` unit; a unit implementing a contract of a unit it may depend on (a technology unit the
  storage contracts, a platform unit its own `api`, a `<feature>/fake` the `api` it fakes); a DI module taking
  the DI module of a unit it may depend on; the entry-point unit building the product units' DI modules.
  A state holder's public interface in an `api` unit is a contract, even in `component` or `viewmodel`.
  Kotlin test source sets may also use exported fake implementations (`arch-package.kt.md`, Tests).
  Nothing else crosses: no other implementation is called across units, no table, and no platform type into
  a platform-free unit (a plugin's `api` unit, `core/api`, the storage contracts unit). An app's UI `api`
  may expose its state holder's UI framework and the Compose model types allowed by `compose.kt.md`;
  this does not permit unrelated platform, ORM or network types in its contracts or models.
- A sub-context depends on another through that one's `api` unit (`command` → `gui/api` to call
  `AddRatingUseCase`). Only the entry-point unit depends on a feature's platform unit (`gui/bukkit`), and
  nothing depends on the entry-point unit. In an app, only the entry-point unit depends on an `impl` unit.
- A use case several sub-contexts need lives in the `api` unit of the sub-context that owns the operation. When
  no owner can be named, the agent asks the user.
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
  permission models, shared functions, shared coroutine scopes, generic classes that units of two sub-contexts
  need (`core/cache/cache4k/<Class>`, moved there once a unit of a second sub-context needs it), small
  platform pieces as packages (`core/coroutine`). It has the same concept → kind shape as any unit. It may be
  split by platform (`core/api`, `core/bukkit`) and, in an app with Compose, into a design-system unit
  (`core/ui`).
- `core` holds no use case and no repository, and depends on no feature unit. Nothing enters it before its
  second consumer.
- A published library (AstraLibs) is a dependency, not the `core` of any project.

### Direction and enforcement

| Inside a unit | may depend on |
|---|---|
| `model` | other `model` packages: of a higher level or of another concept of the unit |
| `api` (contracts) | `model` |
| `usecase` | `api`, `model`, `util` |
| implementations (technology packages and units), `stub` | `api` (the contract they implement and the contracts they call), `model`, `util`, and what sits in their own technology package or unit (`table`, `entity`, `database`, a helper class beside them); a router's implementation also the UI kinds it opens |
| `fake` (Kotlin test implementations) | `api` (the contract it replaces), `model`, `util` |
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

| Between units | may depend on |
|---|---|
| entry-point unit | every product unit; no `<feature>/fake` in production source sets |
| a platform unit (`gui/bukkit`) | its own `api`, other `api` units, `core` and its platform unit (`core/bukkit`), the storage contracts unit |
| an unsplit sub-context (`event-bukkit`) | `api` units, `core` and its platform unit, the storage contracts unit |
| an `api` unit | other `api` units, the platform-free `core` (`core/api`), the storage contracts unit |
| an `impl` unit (app) | its own `api`, other `api` units, `core` |
| a storage technology unit (`data/exposed`) | the storage contracts unit, `core` |
| the storage contracts unit (`data/dao`) | `core` |
| `contract` | nothing of the project |
| `core` (`core/api`) | nothing of the project |
| the platform unit of `core` (`core/bukkit`) | `core/api` |
| the design-system unit of `core` (`core/ui`) | `core/api` |
| `<feature>/fake` | the `api` it fakes |
| a unit that serves or calls a context's routes | its row above, plus that context's `contract` unit |
| a Kotlin test source set | its unit's row above, plus shared fakes from `<feature>/fake` or `testFixtures`; these additions are test-only dependencies |

No cycles between production units or between packages. Test-only dependencies do not become production
edges; each compilation's dependency graph must remain acyclic. Only test source sets consume a
`<feature>/fake` unit. These two tables are the whole list.

A checker knows the fixed kinds by name: `api`, `model`, `usecase`, `util`, `di`, `theme`, `stub`, `warmup`,
`migration`, `error`, `table`, `entity`, `database`, `composable` (the one kind whose sub-packages are kinds
too: `screen`, `component`, `layout`, a project's own word) and `fake` in the Kotlin test or `testFixtures`
tree, or in `commonMain` of a dedicated `<feature>/fake` unit. A technology package is named after a library
the unit depends on (read from its build file), or `file`, `memory`. In a
unit that is wholly one technology, a concept package holds its implementations directly
(`router/BukkitGuiRouter`), and the root package of the entry-point unit holds the classes the platform
constructs. An entry-point or UI kind is a word listed in the checker's config, the project's own words
(`command`, `gui`, `slot`, `expansion`); any other package that holds files is flagged. A unit's type is the
convention plugin its build file applies (one per unit type, `arch-package.kt.md`); the checker's config maps
each plugin to a row of the table above, and a unit without such a plugin is checked by hand.

Every row of these tables, the package names and the naming of implementations are meant to be checked by a
tool in the build; the platform and framework imports of `model`, `api` and `usecase` are the reviewer's call. The checker is not written yet; until
it exists, the skill's checklist is answered by hand.
