## Boundaries between units

This rule says how units relate: what one may depend on, what crosses between them, what is shared, and what
enforces it. The package-layout rule defines the units; the domain rule defines what is inside them.

### The dependency graph

- The units form an acyclic graph. An edge is one of six kinds: a call on a contract or a use case of an
  `api` unit or of the storage contracts unit; a subscription to its events; a use of `core` (its models,
  helpers and scopes); a use of a context's `contract` unit; a unit implementing a contract of a unit it may
  depend on (a technology unit the storage contracts, a platform unit its own `api`, a `<feature>/fake` the
  `api` it fakes); the entry point building every unit's DI module. Nothing else crosses: no implementation is
  called across units, no table, no platform type.
- A sub-context depends on another through that one's `api` unit (`command` → `gui/api` to call
  `AddRatingUseCase`). Only the entry point depends on a feature's platform unit (`gui/bukkit`), and nothing
  depends on the entry point. In an app, only the entry point depends on an `impl` unit.
- A use case several sub-contexts need lives in the `api` unit of the sub-context that owns the operation. When
  no owner can be named, the agent asks the user.
- Storage is reached through its contracts unit (`data/dao`). Only the technology unit (`data/exposed`) and the
  entry point depend on the technology.
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
  look for: it is replaced by a model type and mapped in the implementation.

### `core`

- `core` is the project's common unit for what is not worth a unit of its own: config, translation and
  permission models, shared functions, shared coroutine scopes, generic classes two units need
  (`core/cache/cache4k/<Class>`, moved there once a second unit needs it), small platform pieces as packages (`core/coroutine`). It has the same
  concept → kind shape as any unit. It may be split by platform (`core/api`, `core/bukkit`).
- `core` holds no use case and no repository, and depends on no feature unit. Nothing enters it before its
  second consumer.
- A published library (AstraLibs) is a dependency, not the `core` of any project.

### Direction and enforcement

| Inside a unit | may depend on |
|---|---|
| `model` | nothing of its level |
| `api` (contracts) | `model` |
| `usecase` | `api`, `model`, `util` |
| implementations (technology packages and units), `stub` | the contracts they implement, `model`, `util`, and what sits in their own technology package or unit (`table`, `entity`, `database`, a helper class beside them); a router's implementation also the UI kinds it opens |
| entry-point and UI kinds, the project's own words for them included (`command`, `event`, `gui`, `slot`, `component`, `context`, `route`, `composable` and its sub-packages, `viewmodel`, …), and `warmup`, `migration`, `error` | `usecase`, `api`, `model`, `util`; `theme` for the Compose kinds; the other UI kinds of the same unit, with no cycle between them: a whole depends on its parts (a screen on its components and layouts, a menu on its slots), and a whole is used only by what hosts or opens it (a parent composable, a component's `Render()`, a router's implementation) |
| `theme` (Compose) | `model` |
| `util` | `api`, `model`; `theme` in a Compose unit |
| `di` | everything |

| Between units | may depend on |
|---|---|
| entry point | every unit |
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

No cycles anywhere. These two tables are the whole list.

A checker knows the fixed kinds by name: `api`, `model`, `usecase`, `util`, `di`, `theme`, `stub`, `warmup`,
`migration`, `error`, `table`, `entity`, `database`. Any other package that holds files is a technology package
when it holds an implementation of a contract (a class implementing an interface from an `api` package), and an
entry-point or UI kind otherwise.

Every row of these tables, the package names, the naming of implementations and the imports allowed in
`model`, `api` and `usecase` are meant to be checked by a tool in the build. The checker is not written yet; until
it exists, the skill's checklist is answered by hand.
