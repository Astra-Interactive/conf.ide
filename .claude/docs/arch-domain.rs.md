## Rust: domain building blocks

How the domain rule is written in Rust.

- An entity with invariants is a `struct` with private fields and methods that return a new value or a
  decision; a value object without invariants is a plain `struct` with `pub` fields (the type's own visibility caps
  them) and derives
  `Clone, PartialEq, Eq`.
- A typed identifier is a newtype (`pub(crate) struct PlayerId(Uuid)`) deriving `Copy, Eq, Hash`; a value
  object with an invariant is built by an associated function returning `Result<Self, ModelError>`.
- A sealed family is an `enum` in the model module: the results of a use case, the error families, the events
  of an aggregate. Errors are `thiserror` enums in a library's model; a binary uses them through the
  library's types and never leaks a dependency's error type with `#[from]` across a crate boundary.
- A repository is a `trait` in the `data` block named `<Aggregate>Repository`, `async` where it does I/O,
  object-safe so that use cases hold it as `Arc<dyn JailRepository>`; implementations live one level down in
  the technology file.
- A use case is a `struct` at the context block's root holding its contracts as `dyn` trait objects, with
  one public method named by the verb or `call`. It imports no platform crate.
- Platform or storage representations (a `sqlx::FromRow` struct, a plugin API's location type) live in the
  technology file and convert to and from the model with `From` implementations declared there.
