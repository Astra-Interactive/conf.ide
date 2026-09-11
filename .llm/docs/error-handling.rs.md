## Rust: Error Handling — `Result`

Never use panics for normal control flow in your own application logic. Functions that can fail must return `Result<T, E>` instead of panicking.

Rust's `Result` has a typed error channel:

```rust
Result<T, E>
```

Model domain errors as dedicated error enums, one per domain, with a variant per failure mode. Use `thiserror` to derive `Display` and `Error`:

```rust
#[derive(Debug, thiserror::Error)]
pub enum PacketDecodeError {
    #[error("buffer is empty")]
    EmptyBuffer,
    #[error("varint is longer than 5 bytes")]
    VarIntTooWide,
    #[error("string of {actual} bytes exceeds the {limit} byte limit")]
    StringTooLong { actual: usize, limit: usize },
}
```

Error types carry small, structured payloads. Prefer primitives and domain newtypes over free-form strings; a `String` payload is allowed only where the value genuinely is text (a channel name, a tag key). Never expose a raw third-party error type in a public domain error — wrap it.

Return errors explicitly:

```rust
fn decode_handshake(buffer: &mut impl Buf) -> Result<Handshake, PacketDecodeError> {
    if !buffer.has_remaining() {
        return Err(PacketDecodeError::EmptyBuffer);
    }
    Ok(Handshake { /* ... */ })
}
```

Use `?` to propagate failures upward when the caller handles them:

```rust
fn read_login_start(buffer: &mut impl Buf) -> Result<LoginStart, ConnectionError> {
    let username = buffer.read_string(16).map_err(ConnectionError::Decode)?;
    Ok(LoginStart { username })
}
```

Provide `From` impls so `?` converts errors automatically at layer boundaries. `thiserror`'s `#[from]` does this for you:

```rust
#[derive(Debug, thiserror::Error)]
pub enum ConnectionError {
    #[error(transparent)]
    Decode(#[from] PacketDecodeError),
    #[error("io failure")]
    Io(#[from] std::io::Error),
}
```

Consume a `Result` with `match` when you need to produce one final value:

```rust
let response = match build_status(context) {
    Ok(status) => Response::Ok(status),
    Err(error) => Response::Rejected(error),
};
```

Use `map` to transform a success value, `and_then` to chain fallible operations, and `map_err` to convert error types at boundaries:

```rust
fn encode(&self, buffer: &mut BytesMut) -> Result<(), EncodeError> {
    self.write_payload(buffer)
        .map_err(|nbt_error| EncodeError::Nbt(nbt_error))
}
```

Use `unwrap_or`, `unwrap_or_else`, or `or_else` to convert a failure into a success fallback:

```rust
let protocol = ProtocolVersion::from_number(raw).unwrap_or(ProtocolVersion::UNDEFINED);
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
* `unwrap`/`expect` are acceptable only in tests, in `build.rs`, and in the composition root where a failure to start (bad config, unbindable port, corrupt embedded resource) is unrecoverable and exiting is the intended behavior. Even there, prefer reporting the error and exiting with a non-zero code over a panic message.
* Indexing (`slice[i]`) and integer division panic. In code that touches network input, use `get`, `checked_*`, or an explicit bounds guard.
* Do not silently swallow failures. `let _ = fallible()` requires a comment explaining why ignoring is safe.
* Convert third-party errors at the boundary. Domain layers must not depend on `std::io::Error`, `serde_yaml_ng::Error`, or NBT crate error types.
* An error caused by a remote client is expected, not exceptional: log it at debug level, close the connection, and never let it take down the server or another connection.
* Make expected failure paths explicit, observable, and testable.
* Panics are acceptable only for unexpected, unrecoverable, or programmer errors (broken invariants). A panic in a connection task must not be able to corrupt shared state.
