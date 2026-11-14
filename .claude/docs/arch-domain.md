## Domain building blocks

This rule says what the types of a context are and where their rules live. The package-layout rule says
where the files go; this rule decides what is in them. The building blocks (entity, value object, aggregate,
use case, domain event, factory) apply only inside a context that has business rules, one of whose operations
branches on a value of its model; a CRUD context is model, storage and command, and none of them is forced on
it. The sections Repository, What the model may import and Validation apply to every context.

### Rules live in `util`

- The model is data: a `data class` holds fields, the data classes and enums nested in it that only it uses, a
  `companion object` of constants, and, for a type with an invariant (a value object, an entity, an aggregate
  root), the check of that invariant in its constructor; never a function (Rust adds `new`, `TryFrom`, an accessor
  per private field, having no read-only field, and the type's trait impls; `arch-domain.rs.md`).
  A type has an invariant when some combination of values its field types allow must never exist.
- A rule is a function in `util` that takes what it needs as parameters and returns a copy, a decision or a
  failure; never a member of the type (in Rust, never in the type's own file). One that returns its own type
  (a transition) is an extension of it in `util/<Type>Ext.kt` (in Rust, a method of an `impl <Type>` block in
  `util/<type>_ext.rs`, or of a `<Type>Ext` trait when another crate declares the type). One that returns
  anything else is an extension when its inputs are of one model type
  (`fun Dictionary.canRead(reader: UserId?): Boolean`, `fun Money.exceeds(limit: Money): Boolean`), and a
  top-level function in a file named after the decision when they are of two or more
  (`fun isBailCovered(inmate: JailInmate, deposit: Money): Boolean` in `BailCover.kt`); a typed identifier
  (`…Id`) does not count as one, an input the rule only refers to is passed
  as its identifier, and a factory (`create<Type>`, Factory) and `parse<Type>` (`arch-domain.kt.md`,
  `arch-domain.rs.md`) are top-level functions.
- The `util` is that of the level that uses the rule, whichever unit the type comes from
  (`fun PluginConfig.isRatingMessageLengthAllowed(message: String)` in `gui/api`, over a `core` model); a rule
  of a capability's concept is in the capability's unit (`arch-package.md`, Units 2).
  A rule of a model that two units use is written in the `util` of the model's own unit when its types and
  dependencies are allowed there, else in the `util` of the level that uses it. When no `util` may hold it,
  keep the operation with the owner of its meaning, or extract a rule over types allowed in the model's unit
  and convert the consumer-specific inputs at the edge. Do not add a unit solely to avoid this decision.
- A class that only reads and writes a model's fields is the anaemic smell (a `Helper`, a `Manager`): refuse
  it, and write the rule in `util`.
- A use case integrates and never operates: it loads, calls the rules and saves. A rule operates and never
  integrates: it takes values and returns values.

### Entity, value object, identifier

- An **entity** is a thing with identity and a lifecycle. It carries a typed identifier (`PlayerId`,
  `JailId`), never a bare string or number.
- A **value object** is defined by its fields alone and has no identity. It exists only to guard an invariant
  or to carry a unit the primitive lacks (`Duration`, `Money`, `UniqueWorldKey`); its constructor
  guarantees the invariant. A wrapper that adds no check and no unit is forbidden.
- **Typed identifiers** are value objects, and the one kind of model type a context may share with another.
  Across contexts a thing is referred to by its identifier; inside a context by reference. An identifier lives
  in the `model` of the capability that issues its values; another capability that refers to the thing depends
  on that unit when the tables of `arch-context.md` allow it.
- A domain type carries no kind suffix: `Jail`, not `JailModel` or `JailEntity`. The technology representation
  carries the technology word (`JailRow`, `MoneyDropLocationTable`).
- An entity gets no interface.

### Aggregate

- An **aggregate** is the unit that is changed and saved whole. Its root's constructor checks the invariants
  that span its parts, so a new root is checked whichever rule built it; its rules are extensions that return
  a copy or a failure (`fun Claim.addChunk(chunk: ClaimChunk): Claim`). The repository loads and saves it whole.
- In a context with rules an aggregate is a concept: a package with the same kinds inside (`claim/api`,
  `claim/model`, `claim/util`, `claim/usecase`). The parts that belong to one aggregate (`ClaimChunk` with its
  `ChunkFlag`s) stay in one concept.
- A context without rules has no aggregates. An aggregate whose rules start taking other aggregates as
  arguments is the signal that the boundary is wrong.

### Repository

- The data contract is the repository: `<Aggregate>Repository`, one per aggregate or per model family, in the
  `api` package of the concept it stores (`data.dao.rating.api.RatingRepository`). It speaks the context's
  words (`findUnreconciled(account)`, not `findByAccountAndDateRange`), holds no business rule and extends no
  generic base. An interface whose functions load or save an aggregate is the repository contract, and `Api`,
  `Dao`, `Krate` and `Storage` are not names for it; `Krate`, KStorage's type, stays for an implementation that
  is a krate.
- A cache is part of storage, never of its consumer. One that wraps the whole repository is another
  implementation beside it (`data.exposed.rating.CacheRefreshingRatingRepository` beside
  `ExposedRatingRepository`). One that caches part of it gets its own contract in the same `api`
  (`RatedUsersCache`) and an implementation in the technology unit (`Cache4kRatedUsersCache`). A class it uses
  has its own file beside it (`RefreshingCache`), placed when it is created (`arch-package.md`, Existing code).
- A read that decides nothing is a query function on the repository returning a projection type declared in
  `model`; it does not load the aggregate. A use case is either a command that changes an aggregate or a query
  that only reads, never both.

### Use case

- A use case is named `<Verb><Object>UseCase` (`AddRatingUseCase`, `LowerKillerRatingUseCase`) and lives in
  the `usecase` package of its concept, with one public entry. Its unit and whether it has an interface:
  `arch-package.md`, Units 4–6.
- It exists only when the flow has more than one step: a contract call whose result a model rule judges
  before the next action, or two or more contracts combined. A single contract call with no branch is made
  from the entry point directly, unless a use case of the concept makes that change: then the entry point
  calls the use case.
- One action per class. A use case never calls another use case; an entry point that needs two actions calls
  both.
- A use case holds no domain rule: it orchestrates the rules and the contracts. The rule a new use case needs
  is written in `util`.

### Domain service

There is no domain-service kind. A pure rule is a `util` function. A capability a technology provides
(hashing, sending mail) is a contract in the `api` of its concept with an implementation in a technology package.
When the standard library or a library the project already uses provides that contract with its implementations
(`kotlin.time.Clock` with `Clock.System`), the project uses it and declares none of its own.
The word `Service` appears in no type name, except for a component the platform runs on its own lifecycle,
which lives in `service/`.

### Domain event

- An event type is one a contract publishes as a `Flow` (Rust: a stream); it is a model type in `model` with
  the aggregate it concerns, and its name is a past participle (`PlayerJailed`); a sealed family of events is
  named `<Subject>Event` and its variants are past participles (`TimerEvent.Started`).
- An event another unit of the project listens to sits in the publisher's `api` unit, published through a
  publisher contract there (`val events: Flow<PlayerJailed>`; Rust: a `BoxStream`, `arch-domain.rs.md`); it
  depends on no platform.
  A platform event type (a Bukkit `Event` subclass, `PlayerJailedEvent`) is declared only for other plugins:
  it keeps the platform's `Event` suffix, wraps the model event in the `event` kind of the platform unit, and
  no unit of the project listens to it.
- Listeners sit in the `event` kind of the sub-context that reacts. A class there that listens to events is
  named `<Subject>Listener` (`SitListener`); the `Event` suffix is kept for event types.

### Factory

- A factory exists only when creating an aggregate involves a rule, and then it is a top-level function in the
  aggregate's `util` returning a `Result`
  (`fun createJail(name: String, location: JailLocation): Result<Jail>`), never a companion `create` (in
  Rust, never an associated function of the model type): the model is data. It checks what can fail first and
  returns the failure; the root's constructor checks the invariant.
- The construction of dependencies belongs to `di/` and is not called a factory. A `Factory` class for a
  single implementation is forbidden. The exception is an object that needs arguments known only when it is
  created (a UI component's context and callbacks): its `fun interface Factory` is nested in the type it
  builds, its interface when it has one (Rust cannot nest a trait: a trait `<Type>Factory` in that type's
  file), and a DI module implements it.

### What the model may import

- The model may carry serialization annotations, because a format is not a framework. It never carries a
  platform or ORM base class, import or type, those being what the linter's built-in framework list and the
  project's technology words name: an Exposed row or a Bukkit `Location` stays in its technology
  package or unit, or behind a conversion in the model's own terms (`JailLocation` with
  `toBukkitLocation()` on the platform side). In the unit of a framework's entry point, `model` may hold that
  framework's exception subclasses (the error-handling rule); no other framework type. The `model` of a UI
  unit, one whose build already depends on Compose, may carry Compose types (`Painter`, `Dp`, `Color`) when the
  type holds what the domain type lacks (a painter, a dimension), never as a copy of it; the Kotlin Compose
  rule gives the details.
- One representation per thing: a model lives in the `model` of the level that owns it, and a higher level's
  `model` holds only what several lower levels share. A technology package keeps its own representation only
  when the technology dictates a shape (a table row, a wire format with its own field
  names), and it maps at its own edge. A type with the model's fields and no shape the technology dictates is
  forbidden. The one allowed twin is Rust's `<Type>Parts` struct (`arch-domain.rs.md`).

### Validation

Validation is repeated on purpose, each copy in its own place: an entry point checks the shape of its input
(an argument converter, a request type); the model's constructors check its invariants; the technology
package adds the storage constraint. There is no `validation` package and no validator class that duplicates
a model invariant.
