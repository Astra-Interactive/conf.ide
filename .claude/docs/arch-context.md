## Boundaries between units

This rule says how units relate: what one may depend on, what crosses between them, what is shared, and what
enforces it. The package-layout rule defines the units; the domain rule defines what is inside them.

### The dependency graph

- The units form an acyclic graph. An edge is one of three kinds: a call on a contract or a use case of an
  `api` unit, a subscription to its events, or a use of `core` (its models, helpers and scopes). Nothing else
  crosses: no implementation, no table, no platform type.
- A sub-context depends on another through that one's `api` unit (`command` → `gui/api` to call
  `RatePlayerUseCase`). Nothing depends on a feature's platform unit (`gui/bukkit`) or on the entry point. In an
  app, only the entry point depends on an `impl` unit.
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
  (`core/cache/cache4k/RefreshingCache`), small platform pieces as packages (`core/coroutine`). It has the same
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
| implementations (technology packages and units), `stub` | the contracts they implement, `model` |
| entry-point and UI kinds, the project's own words for them included (`command`, `event`, `gui`, `slot`, `component`, `context`, `route`, `composable`, `viewmodel`, …), and `warmup`, `migration`, `error` | `usecase`, `api`, `model`, `util` |
| `util` | `api`, `model` |
| `di` | everything; nothing depends on it |

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
| `<feature>/fake` | the `api` it fakes |

No cycles anywhere. These two tables are the whole list.

Every row of these tables, the package names, the naming of implementations and the imports allowed in
`model`, `api` and `usecase` are meant to be checked by a tool in the build. The skill names the checker; until
it exists, the skill's checklist is answered by hand.
