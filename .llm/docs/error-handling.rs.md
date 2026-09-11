## Rust: Error Handling — `Result`

Never use panics for normal control flow in your own application logic. Functions that can fail must return `Result<T, E>` instead of panicking.

Rust's `Result` has a typed error channel:

```rust
Result<T, E>
```

Model domain errors as dedicated error enums, one per domain, with a variant per failure mode. Use `thiserror` to derive `Display` and `Error`:

```rust
#[derive(Debug, thiserror::Error)]
pub enum OrderError {
    #[error("cart is empty")]
    EmptyCart,
    #[error("order of {actual} items exceeds the {limit} item limit")]
    TooManyItems { actual: usize, limit: usize },
    #[error("customer {0} does not exist")]
    UnknownCustomer(CustomerId),
}
```

Error types carry small, structured payloads. Prefer primitives and domain newtypes over free-form strings; a `String` payload is allowed only where the value genuinely is text (a file name, a header key). Never expose a raw third-party error type in a public domain error — wrap it.

Return errors explicitly:

```rust
fn validate_order(order: &Order) -> Result<(), OrderError> {
    if order.items.is_empty() {
        return Err(OrderError::EmptyCart);
    }
    Ok(())
}
```

Use `?` to propagate failures upward when the caller handles them:

```rust
fn place_order(&self, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError> {
    let order = Order::from_command(command)?;
    validate_order(&order)?;
    let order_id = self.repository.save(order)?;
    Ok(order_id)
}
```

Provide `From` impls so `?` converts errors automatically at layer boundaries. `thiserror`'s `#[from]` does this for you:

```rust
#[derive(Debug, thiserror::Error)]
pub enum PlaceOrderError {
    #[error(transparent)]
    Invalid(#[from] OrderError),
    #[error("could not persist the order")]
    Storage(#[from] OrderRepositoryError),
}
```

Consume a `Result` with `match` when you need to produce one final value:

```rust
let response = match service.place_order(command) {
    Ok(order_id) => Response::Created(order_id),
    Err(error) => Response::Rejected(error),
};
```

Use `map` to transform a success value, `and_then` to chain fallible operations, and `map_err` to convert error types at boundaries. Pass the variant constructor itself to `map_err`; a closure that only forwards its argument fails `clippy::redundant_closure`:

```rust
fn load_order(&self, id: OrderId) -> Result<Order, OrderRepositoryError> {
    let raw = fs::read_to_string(self.path_for(id)).map_err(OrderRepositoryError::Io)?;
    serde_json::from_str(&raw).map_err(OrderRepositoryError::Deserialize)
}
```

Use `unwrap_or`, `unwrap_or_else`, or `or_else` to convert a failure into a success fallback:

```rust
let currency = Currency::from_code(raw_code).unwrap_or(Currency::DEFAULT);
```

Rules:

* Prefer:
    * `Result<T, E>` with a domain error enum for operations that can fail.
    * `Option<T>` only when absence is the only meaningful failure.
    * A per-use-case result enum when different success outcomes must be handled explicitly (the sealed-hierarchy analog).
* Use `?` for propagation and `From` impls for error conversion.
* Use `map` for pure success-value transformations, `and_then` for chaining, `map_err` for error conversion.
* Use `unwrap_or`/`unwrap_or_else`/`or_else` for fallback behavior.
* Do not use `unwrap()`, `expect()`, `panic!`, `todo!`, or `unimplemented!` in library/application logic.
* `unwrap`/`expect` are acceptable only in tests, in `build.rs`, and in the composition root where a failure to start (bad config, unbindable port, missing embedded resource) is unrecoverable and exiting is the intended behavior. Even there, prefer reporting the error and exiting with a non-zero code over a panic message.
* Indexing (`slice[i]`), division by zero, and integer overflow in debug builds panic. In code that handles untrusted input, use `get`, `checked_*`, or an explicit bounds guard.
* Do not silently swallow failures. `let _ = fallible()` requires a comment explaining why ignoring is safe.
* Convert third-party errors at the boundary. Domain layers must not depend on `std::io::Error`, `serde_json::Error`, or any other crate's error type.
* An error caused by an external caller (a client request, a malformed input file) is expected, not exceptional: log it at debug level, reject that one request, and never let it take down the process or other requests.
* Make expected failure paths explicit, observable, and testable.
* Panics are acceptable only for unexpected, unrecoverable, or programmer errors (broken invariants). A panic in one task must not be able to corrupt shared state.
