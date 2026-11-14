## Rust: Error Handling — `Result`

### Choosing the failure type

| Situation                                                                               | Use                                     |
|-----------------------------------------------------------------------------------------|-----------------------------------------|
| Absence is the only meaningful failure                                                  | `Option<T>`                             |
| Caller needs to know that it failed and why, but does not branch on the kind of failure | `Result<T, E>`, `E` the error family    |
| Caller must handle several outcomes differently                                         | per-use-case `enum`                     |
| Programmer error or broken invariant                                                    | panic: `assert!`, `unreachable!`        |

Never panic for an expected business or validation failure: a panic is reserved for bugs. A framework that
takes a failure through a trait of its own (a web framework's response trait) gets a dedicated error enum in the
`model` of the framework's entry-point unit, returned only from that framework's entry point (`route`); the
`impl` of the framework's trait that turns it into the reply lives in `error`. Rust needs no counterpart of
Kotlin's thrown framework exception: the framework reads the failure from the return value.

A panic ends only its own task: the task's scope logs it (`async.rs.md`, Tasks), and a critical section that
computes first and writes once leaves shared state as it was before the panic (`async.rs.md`, Shared state and
locks).

### Contract when `Result` is chosen

Choose the failure type from the table above: absence alone uses `Option`, and outcomes the caller handles
differently use a per-use-case enum. This section applies when that choice is `Result<T, E>`. Rust's `Result`
names its error type, so `E` is the error family of the contract. Model domain errors as one `enum` per family
deriving `Debug` and `thiserror::Error`: a variant per failure, its `#[error("…")]` text the message, its fields
the values the message names. A cause from code you do not own is the `#[source]` field
`source: Box<dyn Error + Send + Sync>`, Rust's form of Kotlin's `cause: Throwable`, so the family names no foreign
error type and stays `Send + Sync` (API Guidelines C-GOOD-ERR). An error of a family reaches a panic only in the
`new` of a model type with an invariant (`arch-domain.rs.md`); everywhere else your own code returns it.

```rust
// model/order_error.rs: the enum and every variant, one file
#[derive(Debug, thiserror::Error)]
pub(crate) enum OrderError {
    #[error("order payload is blank")]
    Parse,
    #[error("order {} is closed", .id.0)]
    Closed { id: OrderId },
    #[error("could not load order {}", .id.0)]
    Load {
        id: OrderId,
        #[source]
        source: Box<dyn Error + Send + Sync>,
    },
}
```

```rust
pub(crate) fn parse_order(raw: &str) -> Result<Order, OrderError> {
    if raw.trim().is_empty() {
        return Err(OrderError::Parse);
    }
    Ok(Order { /* ... */ })
}

// util/order_ext.rs
impl Order {
    pub(crate) fn ensure_open(self) -> Result<Order, OrderError> {
        if self.closed {
            return Err(OrderError::Closed { id: self.id });
        }
        Ok(self)
    }
}
```

### Where error types live

- An error enum that a contract's signature names, or that its implementations return in `Err`, lives in the
  `model` module of that contract's level, in one file with all its variants: `model/order_error.rs` holds
  `OrderError`.
- A per-use-case result enum (`PlaceOrderResult`) lives in the same `model`, with its failure variants next to
  the success ones.
- Any other error enum is its own file in the `model` of the level that uses it, even one that never leaves one
  implementation, never a private enum inside the file that returns it.
- An old `error.rs` or `errors` module stays as it is; new error types of its concept still go to `model/`.
  Such a module of error types is not the `error` kind, Kotlin's old `exception/` package under another name, and
  receives no failure handler: a handler that turns a failure into the user's reply goes to the `error` kind of
  the mechanism that fails (`arch-package.md`, Concepts and kinds 3).

### Boundaries: converting foreign errors

`map_err` is the boundary tool: at a call of code you do not own that fails (a third-party client, I/O,
serialization), translate its error into a variant of the family right there, so inner layers never see a
foreign error type.

```rust
fn load_order(&self, id: OrderId) -> Result<Order, OrderError> {
    let raw = fs::read_to_string(self.path_of(id)).map_err(|error| OrderError::Load {
        id,
        source: error.into(),
    })?;
    parse_order(&raw)
}
```

`#[from]` joins the project's own families, so that `?` turns one into another
(`PlaceOrderError::Order(#[from] OrderError)`). A foreign error type is never a field of a family, so `#[from]`
never names one. Your own logic returns `Err` and is never wrapped in `std::panic::catch_unwind`, which std
says is not "a general try/catch mechanism".

Kotlin's Coroutines section, which rethrows `CancellationException` after `runCatching`, has no Rust
counterpart: a Rust future is cancelled by being dropped, not by an error value, so no `?`, `match` or `map_err`
can swallow a cancellation (`async.rs.md`, Tasks).

### Composing fallible steps

`?` is Kotlin's `getOrElse { return … }`: chain steps with `?`, one step per `let`, and the happy path stays
flat.

```rust
fn compute_order_total(raw: &str) -> Result<Money, OrderError> {
    let order = parse_order(raw)?;
    let open_order = order.ensure_open()?;
    Ok(open_order.total)
}
```

Use `map` for a pure transformation of the success value and `unwrap_or` or `unwrap_or_else` for a fallback
value:

```rust
let total: Result<Money, OrderError> = parse_order(raw).map(|order| order.total);

let total_or_zero: Money = total.unwrap_or(Money::ZERO);
```

### Consuming a `Result`

Use `match` when you need one final value, and `if let Err(error)` when the only thing left is a side effect
such as logging. That is Kotlin's `onFailure`; `inspect_err` is not its form here, because it returns the
`Result` again, which must itself be consumed:

```rust
let reply = match result {
    Ok(order) => OrderReply::Accepted(order.id),
    Err(error) => OrderReply::Rejected(error.to_string()),
};

if let Err(error) = save_order(order) {
    tracing::warn!(error = &error as &dyn Error, "Could not save order");
}
```

`unwrap` and `expect` are Kotlin's `getOrThrow`: allowed only where a panic is the intended contract, in tests,
in a build script and in startup validation. Outside tests the call carries
`#[expect(clippy::unwrap_used, reason = "…")]` or `#[expect(clippy::expect_used, reason = "…")]`. The fixture tree
and the helpers of `tests/it` that are not `#[test]` functions are test code, but clippy treats only `#[cfg(test)]`
modules and `#[test]` functions as tests: an `unwrap` or `expect` there carries the same marker. Never use them
to skip handling a failure. Kotlin also allows `getOrThrow` for an API that takes failures only as exceptions;
a Rust API reads a failure from its return type, so that case has no Rust form.

Log a failure once, at the call site that has enough context. Do not log and return it with `?`, and never
discard a `Result`: no call whose `Result` is left unused, and no `let _ =` on it, with one exception. The send
of a channel whose failures the design accepts may be discarded: `oneshot::Sender::send`,
`mpsc::Sender::try_send`, `mpsc::UnboundedSender::send` and `broadcast::Sender::send`. Their failures are a gone
receiver, no subscriber, or a full buffer the producer chose (`no-callbacks.rs.md`); a full buffer drops the
event silently, as Kotlin's `trySend` does. The statement is `let _ = …;` under
`#[expect(clippy::let_underscore_must_use, reason = "<which failure and why it is accepted>")]`:

```rust
#[expect(
    clippy::let_underscore_must_use,
    reason = "the receiver is gone only when the caller was cancelled"
)]
let _ = sender.send(outcome);
```

The attribute alone does not hold the exception to the four sends: every `Result` is `must_use`, so it is
fulfilled on any discarded `Result`, and it fails the build (`unfulfilled_lint_expectations`) only on a value
that is not `must_use`. The limit to the four sends is held by the reviewer, and later by a linter check that
reports the attribute on any other call. A send whose loss matters (a payment confirmation) is not under it: it is
`mpsc::Sender::send(…).await`, or an unbounded channel, chosen with the buffer.
