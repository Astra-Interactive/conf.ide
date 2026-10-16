## Domain building blocks

This rule says what the types of a context are and where their rules live. The package-layout rule says
where the files go; this rule decides what is in them. It applies only inside a context that has business
rules. A CRUD context is model, storage and command, and none of the building blocks below is forced on it.

### Rules live on the model

- A rule about one type is a function of that type in its `model` file: a method or an extension that returns
  a copy or a decision, taking what it needs as parameters (`fun JailInmate.isSentenceOver(now: Instant)`).
- A rule spanning several types is a function in `model` named after the decision.
- A class that only reads and writes a model's fields is the anaemic smell: refuse it, and move the rule into
  the model.
- A use case integrates and never operates: it loads, calls the model and saves. A model function operates and
  never integrates: it takes values and returns values.

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

- An **aggregate** is the unit that is changed and saved whole. Its root is the only type through which its
  parts are changed. The repository loads and saves the aggregate whole.
- In a context with rules an aggregate is a module of the context: a sub-package with the same roles inside,
  created at three or more files or storage of its own, as the package-layout rule says. The parts that belong
  to one aggregate (`ClaimChunk` with its `ChunkFlag`s) stay in one module.
- A context without rules has no aggregates. An aggregate whose methods start taking other aggregates as
  arguments is the signal that the boundary is wrong.

### Repository

- The context's data contract is the repository: `<Aggregate>Repository`, one per aggregate or per model
  family, in `data`. It speaks the context's words (`findUnreconciled(account)`, not
  `findByAccountAndDateRange`), holds no business rule and extends no generic base. `Api`, `Dao`, `Krate` and
  `Storage` are not contract names; `Krate` stays for an implementation that is a krate.
- A read that decides nothing is a query function on the repository returning a projection type declared in
  `model`; it does not load the aggregate. A use case is either a command that changes an aggregate or a query
  that only reads, never both.

### Use case

- A use case is a class at the context root named by its verb (`JailPlayer`, `FreeInmate`), with one public
  entry and no interface. It exists only when it decides something or combines two or more contracts; an
  entry point that merely reads or writes storage calls the contract directly.
- One action per class. A use case never calls another use case; an entry point that needs two actions calls
  both.
- A use case holds no domain rule: it orchestrates the model and the contracts. A rule found in a use case
  moves to `model`.

### Domain service

There is no domain-service kind. A pure rule is a `model` function. A capability a technology provides
(hashing, sending mail, a clock) is a contract at its role level with a technology implementation beneath it.
The word `Service` appears in no type name, except for a component the platform runs on its own lifecycle,
which lives in `service/`.

### Domain event

- An event type is a model type, named in the past tense (`PlayerJailed`), in `model` with the aggregate it
  concerns. It is published through the platform's event bus or through the context's own publisher contract.
- Listeners sit in `event/` of the context that reacts, which may be another context.
- An event another context listens to is part of the publisher's public surface and is placed with its
  contracts.

### Factory

- A factory exists only when creating an aggregate involves a rule, and then it is a function in the
  aggregate's `model` file: a companion `create` or a top-level function returning a `Result`.
- The construction of dependencies belongs to `di/` and is not called a factory. A `Factory` class for a single
  implementation is forbidden.

### What the model may import

- The model may carry serialization annotations, because a format is not a framework. It never carries a
  platform or ORM base class, import or type: an Exposed row or a Bukkit `Location` stays in
  `data/<technology>` or behind a conversion in the model's own terms (`JailLocation` with
  `toBukkitLocation()` on the platform side).
- One model per context: the context's `model` is the one model. A technology package keeps its own
  representation only when the technology dictates a shape (a table row, a wire format with its own field
  names), and it maps at its own edge. A type with the same fields as the model "for separation" is forbidden.

### Validation

Validation is repeated on purpose, each copy in its own place: an entry point checks the shape of its input
(an argument converter, a request type); the model guards invariants in value-object constructors and
aggregate methods; the technology package adds the storage constraint. There is no `validation` package and no
validator class that duplicates a model invariant.
