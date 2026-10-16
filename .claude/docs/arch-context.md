## Cross-context boundaries

This rule says how contexts relate: what one may depend on, what crosses between them, what is shared, and
what enforces it. The package-layout rule defines the contexts; the domain rule defines what is inside them.

### The context map is the dependency graph

- The map of contexts is the dependency graph between units. It is acyclic, and every edge is one of three
  kinds: a call on the provider's published contract, a subscription to the provider's events, or a shared
  typed identifier from the kernel. Nothing else crosses: no repository, no table, no technology type.
- A consumer depends on the provider's `api` unit; a context that another context needs is split before the
  dependency is declared (package-layout rule, Units 3). Nothing but the entry-point unit depends on an `impl`
  or unsplit context unit, and only to construct the composition root. An `api` unit may depend on `core`, the
  kernel and other `api` units, never on any `impl`.
- A decision that spans two contexts is a use case in the context that owns the rule, which calls the other
  context's contract. There is no orchestration layer above the contexts; the entry point only wires.
- A context publishes general events, shaped for no single consumer. Its contract is drawn as a boundary, not
  for the convenience of the current caller.

### What crosses

- A contract's signatures use the provider's own model types, behaviour included, placed with the contract.
  An identifier is preferred over a whole object where the consumer only refers to something. An outward copy
  of a type exists only when the public surface must hide fields.
- A context never reads another context's tables or files. A read-only need is served by a query on the
  provider's contract returning a projection.
- A server and its client share wire types through a `<context>/contract` unit of serializable types and route
  constants; neither side's model crosses the wire.

### The anti-corruption layer

- When the provider's model is not yours to control, an external library, a platform API, a remote system, a
  third-party plugin, the consumer declares its own contract for what it needs and translates at its edge. This
  is mandatory for such providers and optional for a sibling context of the same repository, whose published
  `<Context>Api` is used directly by default.
- Its shape is the `integration` role: the contract in `integration/`, in the consumer's own words; the
  implementation one level down in a package named by the system (`integration/luckperms/`), holding both what
  the context calls on that system and the provider the system calls on the context
  (`integration/vault/VaultEconomyProvider`); the translations in `mapping/` when more than one file shares
  them, otherwise inside the implementation. A provider the external system calls is an entry point of the
  context and follows the entry-point row below.
- A framework type that leaks into a contract (`Page`, `Pageable`, a plugin's `Location`) is the violation to
  look for: it is replaced by a model type and mapped in the implementation.

### Shared units

- `core` holds platform infrastructure that knows no domain word: the connection, serialization, the command
  framework, the DI base, shared coroutine scopes. Small pieces live in it as capability-named packages
  rather than as tiny units.
- The domain kernel holds only the typed identifiers and generic value objects two or more contexts share, and
  is named for what it holds.
- Nothing enters either before its second consumer. Business logic never enters either. A kernel that grows is
  the signal that two contexts should merge.
- A published library (AstraLibs) is the company's kit, consumed as a dependency; it is neither `core` nor the
  kernel of any project.

### Direction and enforcement

| Inside a context | may depend on |
|---|---|
| `model` | nothing in the context |
| contracts (`data`, `integration`) | `model` |
| use cases, `Default<Context>Api` | contracts, `model` |
| technology packages (`data/<tech>`, the adapters in `integration/<system>`), `mapping` | the contracts above them, `model` |
| entry points (`command`, `event`, `service`, `job`, `route`, `composable`, `viewmodel`) and the providers in `integration/<system>` | use cases, contracts, `model` |
| `di` | everything; nothing depends on it |

| Between units | may depend on |
|---|---|
| entry point | every context unit (`impl` or unsplit), `core`, the kernel, `contract` units |
| a context unit (`impl` or unsplit) | its own `api`, other contexts' `api`, `core`, the kernel, its `contract` unit |
| `api` | other `api` units, `core`, the kernel |
| `contract` | nothing of the project |
| `core`, the kernel | nothing of the project |
| `<feature>/fake` | the `api` it fakes |

No cycles anywhere. These two tables are the whole list.

Every row of these tables, the package names, the naming of implementations and the imports allowed in
`model`, use cases and contracts are meant to be checked by a tool in the build, because a rule that no tool
checks decays. The skill names the checker; until it exists, the skill's checklist is answered by hand.
