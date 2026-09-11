## Testing

When writing a test, make sure that:

* Test domain logic without sockets, runtimes, or frameworks.
* Test application logic with fake implementations of the ports (`IdSource`, `Clock`, and the project's own traits).
* Keep I/O-facing code thin and behind traits so everything else is host-testable.
* Avoid mocking value objects and simple data structs.
* Prefer fakes over mocks: hand-written structs implementing the trait, recording state, when behavior matters.
* Tests should verify expected behavior, not implementation details.
* Do not write tests that simply mirror the current code structure.
* Test names must use `snake_case`.
* Prefer `given_when_then` structure in test names.
* You are testing the expected business logic, not the actual one.
* Prefer splitting code into testable functions/chunks if that doesn't affect the public API.
* Test coverage for new tests MUST always be 100%.
* The aim of the tests is to validate the intended behavior/contract and reveal bugs, not to lock in incidental current behavior or implementation details.
* If you're not sure what the business logic of the type is, ask the user.
* Feel free to modify base traits/types to improve their testability, but ask the user first about all changes in base traits/types.
* Tests should cover as many scenarios and edge cases as possible without duplicating existing tests.

**Highest-risk areas in this codebase** — a wire-format server. Focus edge cases here:

* varint/varlong boundaries: `0`, `127`, `128`, `2^21-1`, `2^28-1`, `u32::MAX`, truncated input, over-wide encodings.
* String limits measured in both bytes and characters, with multi-byte UTF-8 landing exactly on the boundary.
* Bit packing (block position, bit sets, palettes) including negative coordinates and boundary values.
* Version gating: an encoder branch guarded by `>= V` must be tested at `V` and at the version immediately below it.
* Truncated, oversized, and malformed input on every decode path — it arrives from the network.
* Stream fragmentation: the same byte stream fed in one-byte chunks must decode identically.

**Byte-level parity is verified by golden fixtures, not by hand-written assertions.** Do not hand-copy expected packet bytes into a test file; generate them from the oracle and compare whole buffers. Hand-written byte literals belong only in small primitive tests (varint, position packing).

Example:

```rust
#[test]
fn given_protocol_below_1_16_when_login_success_is_encoded_then_uuid_is_written_as_string() {
    let packet = LoginSuccess::new(KNOWN_UUID, "Player".to_owned(), None);
    let mut buffer = BytesMut::new();

    packet.encode(&mut buffer, ProtocolVersion::V1_15_2).expect("encode");

    assert_eq!(buffer.read_string(36).expect("string"), KNOWN_UUID.hyphenated().to_string());
}
```

Good test focus:

```rust
#[test]
fn given_stream_split_into_single_bytes_when_decoded_then_frames_match_unsplit_decode()
```

Bad test focus:

```rust
#[test]
fn given_encode_when_called_then_write_varint_is_called_once()
```

The second test verifies an implementation detail. The first verifies the expected behavior of the component.

Example fake:

```rust
struct FixedIdSource {
    entity_id: i32,
}

impl IdSource for FixedIdSource {
    fn next_entity_id(&self) -> i32 {
        self.entity_id
    }
}
```

**Test layout**: `#[cfg(test)] mod tests` at the bottom of the source file for unit tests; `tests/` directory for integration tests and golden-fixture comparisons.

**Frameworks**: the built-in `#[test]` harness. `tokio::test` for async application tests, `tokio::io::duplex` for in-process client/server transcripts instead of real sockets.

**To run tests:** `cargo test --workspace`.
