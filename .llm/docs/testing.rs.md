## Testing

When writing a test, make sure that:

* Test domain logic without sockets, runtimes, or frameworks.
* Test application logic with fake implementations of the ports (the project's own traits).
* Keep I/O-facing code thin and behind traits so everything else is testable in-process.
* Avoid mocking value objects and simple data structs.
* Prefer fakes over mocks: hand-written structs implementing the trait and recording state, when behavior matters.
* Tests should verify expected behavior, not implementation details.
* Do not write tests that simply mirror the current code structure.
* Test names must use `snake_case`.
* Prefer `given_when_then` structure in test names.
* You are testing the expected business logic, not the actual one.
* Prefer splitting code into testable functions/chunks if that doesn't affect the public API.
* New code MUST be covered by tests at 100%.
* The aim of the tests is to validate the intended behavior/contract and reveal bugs, not to lock in incidental current behavior or implementation details.
* If you're not sure what the business logic of the type is, ask the user.
* Feel free to modify base traits/types to improve their testability, but ask the user first about all changes in base traits/types.
* Tests should cover as many scenarios and edge cases as possible without duplicating existing tests.
* Focus on concurrency corner cases: state shared through `Arc`/`Mutex`, task cancellation, ordering between async tasks.
* Anything that crosses a process boundary is tested with truncated, oversized, and malformed input.

Example:

```rust
#[test]
fn given_empty_cart_when_order_is_created_then_returns_cart_is_empty() {
    let use_case = CreateOrderUseCase::new(FakeOrderRepository::new(), FakePaymentGateway::new());

    let result = use_case.execute(CreateOrderCommand {
        customer_id: CustomerId(1),
        items: Vec::new(),
    });

    assert_eq!(CreateOrderResult::CartIsEmpty, result);
}
```

Good test focus:

```rust
#[test]
fn given_existing_active_customer_when_order_is_created_then_order_is_saved()
```

Bad test focus:

```rust
#[test]
fn given_create_order_when_execute_called_then_repository_save_called_once()
```

The second test verifies an implementation detail. The first verifies the expected behavior of the use case.

Example fake:

```rust
struct FakeOrderRepository {
    orders: RefCell<HashMap<OrderId, Order>>,
}

impl OrderRepository for FakeOrderRepository {
    fn find_by_id(&self, id: OrderId) -> Option<Order> {
        self.orders.borrow().get(&id).cloned()
    }

    fn save(&self, order: Order) -> SaveOrderResult {
        self.orders.borrow_mut().insert(order.id, order);
        SaveOrderResult::Saved
    }
}
```

### Where tests live

* Unit tests go into `#[cfg(test)] mod tests` at the bottom of the source file. Rust keeps unit tests
  next to the code because a child module sees the parent's private items; this is the only way to test
  a private function without widening its visibility. The module-organization rule does not apply
  inside `#[cfg(test)]`.
* A long test module may move to its own file without losing private access: keep
  `#[cfg(test)] mod tests;` at the bottom of `order_pricing.rs` and put the body into
  `order_pricing/tests.rs`.
* A fake used by one test module stays in that module. Fakes shared by several test modules go to
  `src/test_support/`, one fake per file, declared as `#[cfg(test)] pub(crate) mod test_support;` in
  `lib.rs`. Fakes shared across crates go to a dedicated `<name>-test-support` crate pulled in as a
  dev-dependency.
* Integration tests, which see only the public API, live in the crate's `tests/` directory.

**Frameworks**: the built-in `#[test]` harness. `tokio::test` for async tests; `tokio::io::duplex` for
in-process client/server pairs instead of real sockets.

**To run tests:** `cargo test --workspace`.
