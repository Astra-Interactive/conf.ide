## Domain building blocks

This rule says what the types of a context are and where their rules live. The package-layout rule says
where the files go; this rule decides what is in them. The building blocks (entity, value object, aggregate,
use case, domain event, factory) apply only inside a context that has business rules; a CRUD context is
model, storage and command, and none of them is forced on it. The sections Repository, What the model may
import and Validation apply to every context.

### Rules live in `util`

- The model is data: a `data class` holds fields and, when it is a value object with an invariant, the check
  of that invariant in its constructor; nothing else. A rule about one type is an extension of that type in
  `util/<Type>Ext.kt`, returning a copy or a decision and taking what it needs as parameters
  (`fun JailInmate.isSentenceOver(now: Instant)` in `jail/util/JailInmateExt.kt`,
  `fun Dictionary.canRead(user: User?)` in `dictionary/util/DictionaryExt.kt`). It is never a member of the
  type, and never a top-level function that takes the type as a parameter.
- A rule spanning several types is a top-level function in the same `util`, in a file named after the
  decision (`fun isWithinLimit(transfer: Transfer, limit: AccountLimit): Boolean` in `TransferLimit.kt`).
- The `util` is that of the level that uses the rule, whichever unit the type comes from
  (`fun AstraRatingConfig.isRatingMessageLengthAllowed(message: String)` in `gui/api`, over a `core` model).
  A rule two units use moves to the `util` of the model's own unit, so that it exists once.
- A class that only reads and writes a model's fields is the anaemic smell (a `Helper`, a `Manager`): refuse
  it, and write the rule as an extension.
- A use case integrates and never operates: it loads, calls the rules and saves. A rule operates and never
  integrates: it takes values and returns values.

### Entity, value object, identifier

- An **entity** is a thing with identity and a lifecycle. It carries a typed identifier (`PlayerId`,
  `JailId`), never a bare string or number.
- A **value object** is defined by its fields alone and has no identity. It exists only to guard an invariant
  or to carry a unit or meaning the primitive lacks (`Duration`, `Money`, `UniqueWorldKey`); its constructor or
  factory guarantees the invariant. A wrapper that adds no check and no meaning is forbidden.
- **Typed identifiers** are value objects, and the one kind of model type a context may share with another.
  Across contexts a thing is referred to by its identifier; inside a context by reference.
- A domain type carries no kind suffix: `Jail`, not `JailModel` or `JailEntity`. The technology representation
  carries the technology word (`JailRow`, `MoneyDropLocationTable`).
- An entity gets no interface.

### Aggregate

- An **aggregate** is the unit that is changed and saved whole. Its parts are changed only through the rules
  of its root, extensions that return a copy (`fun Claim.addChunk(chunk: ClaimChunk): Claim`). The repository
  loads and saves the aggregate whole.
- In a context with rules an aggregate is a concept: a package with the same kinds inside (`claim/api`,
  `claim/model`, `claim/util`, `claim/usecase`). The parts that belong to one aggregate (`ClaimChunk` with its
  `ChunkFlag`s) stay in one concept.
- A context without rules has no aggregates. An aggregate whose rules start taking other aggregates as
  arguments is the signal that the boundary is wrong.

### Repository

- The data contract is the repository: `<Aggregate>Repository`, one per aggregate or per model family, in the
  `api` package of the concept it stores (`data.dao.rating.api.RatingRepository`). It speaks the context's words (`findUnreconciled(account)`, not
  `findByAccountAndDateRange`), holds no business rule and extends no generic base. `Api`, `Dao`, `Krate` and
  `Storage` are not names for the repository contract; `Krate` stays for an implementation that is a krate.
- A cache is part of storage, never of its consumer. One that wraps the whole repository is another
  implementation beside it (`data.exposed.rating.CachedRatingRepository` beside `ExposedRatingRepository`).
  One that caches part of it gets its own contract in the same `api` (`RatedUsersCache`) and an implementation
  in the technology unit (`Cache4kRatedUsersCache`). A class it uses has its own file beside it, or in `core`
  when two units use it (`core/cache/cache4k/RefreshingCache`).
- A read that decides nothing is a query function on the repository returning a projection type declared in
  `model`; it does not load the aggregate. A use case is either a command that changes an aggregate or a query
  that only reads, never both.

### Use case

- A use case is named `<Verb><Object>UseCase` (`RatePlayerUseCase`, `LowerKillerRatingUseCase`) and lives in
  the `usecase` package of its concept, with one public entry and no interface. In a plugin it lives in the
  `api` unit of the sub-context that owns the operation; other sub-contexts depend on that unit. It never
  lives in `core`.
- It exists only when the flow has more than one step: a contract call whose result a model rule judges
  before the next action, or two or more contracts combined. A single contract call with no branch is made
  from the entry point directly.
- One action per class. A use case never calls another use case; an entry point that needs two actions calls
  both.
- A use case holds no domain rule: it orchestrates the rules and the contracts. A rule found in a use case
  moves to `util` as an extension of its type.

### Domain service

There is no domain-service kind. A pure rule is a `util` function. A capability a technology provides
(hashing, sending mail, a clock) is a contract in the `api` of its concept with an implementation in a technology package.
The word `Service` appears in no type name, except for a component the platform runs on its own lifecycle,
which lives in `service/`.

### Domain event

- An event type is a model type in `model` with the aggregate it concerns, named in the past tense
  (`PlayerJailed`); a sealed family of events is named `<Subject>Event` and its variants in the past tense
  (`TimerEvent.Started`). It is published through the platform's event bus or through a publisher contract in
  `api`. A platform event type the project declares (a Bukkit `Event` subclass) keeps the platform's `Event`
  suffix (`PlayerJoinedEvent`) and lives in the `event` kind of the platform unit. The suffix is meant to be
  checked by a tool, the past tense by the reviewer.
- Listeners sit in the `event` kind of the sub-context that reacts.
- An event another unit listens to lives in the `api` unit of the publisher, with its contracts.

### Factory

- A factory exists only when creating an aggregate involves a rule, and then it is a top-level function in
  the aggregate's `util` returning a `Result` (`fun createJail(name: String, location: JailLocation):
  Result<Jail>`), never a companion `create`: the model is data.
- The construction of dependencies belongs to `di/` and is not called a factory. A `Factory` class for a single
  implementation is forbidden. The exception is an object that needs arguments known only when it is created
  (a UI component's context and callbacks): its `fun interface Factory` is nested in the class it builds, and a
  DI module implements it.

### What the model may import

- The model may carry serialization annotations, because a format is not a framework. It never carries a
  platform or ORM base class, import or type: an Exposed row or a Bukkit `Location` stays in its technology
  package or unit, or behind a conversion in the model's own terms (`JailLocation` with
  `toBukkitLocation()` on the platform side). The `model` of a UI unit, one whose build already depends on
  Compose, may carry Compose types (`Painter`, `Dp`, `Color`) when the type holds what the domain type lacks
  (a painter, a dimension), never as a copy of it; the Kotlin Compose rule gives the details.
- One representation per thing: a model lives in the `model` of the level that owns it, and a higher level's
  `model` holds only what several lower levels share. A technology package keeps its own representation only
  when the technology dictates a shape (a table row, a wire format with its own field
  names), and it maps at its own edge. A type with the same fields as the model "for separation" is forbidden.

### Validation

Validation is repeated on purpose, each copy in its own place: an entry point checks the shape of its input
(an argument converter, a request type); the model guards invariants in value-object constructors and in the
aggregate's rules in `util`; the technology package adds the storage constraint. There is no `validation` package and no
validator class that duplicates a model invariant.
