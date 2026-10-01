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
pub(crate) struct FakeOrderRepository {
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

* Tests never live in a source file. Each crate has a `test/` directory next to `src/`, the way a Gradle unit has `src/test` next to `src/main`, and the two trees mirror each other: `src/order/pricing.rs` is tested by `test/order/pricing_test.rs`.
* The test tree is declared once, as the last item of `src/lib.rs`, with nested blocks exactly like the source tree:

  ```rust
  #[cfg(test)]
  #[path = "../test"]
  mod test {
      mod order {
          mod pricing_test;
      }
  }
  ```

* The test tree is part of the crate: it sees `pub(crate)` items, the analog of Kotlin `internal`, and imports them by path (`use crate::order::Pricing;`). A private function that needs its own test becomes `pub(crate)`.
* A fake lives in `fake/` inside the concept of the trait it replaces: `test/order/fake/fake_order_repository.rs`, declared in the test block and re-exported with `pub(crate) use` for the tests that need it. A fake that other crates need lives in a `<name>-test-support` crate pulled in as a dev-dependency, instead of a copy in each crate.
* Integration tests, which see only the public API, live in Cargo's `tests/` directory. The mirrored unit-test tree never goes there: Cargo compiles `tests/*.rs` and `tests/*/main.rs` as separate crates.

**Frameworks**: the built-in `#[test]` harness. `tokio::test` for async tests; `tokio::io::duplex` for
in-process client/server pairs instead of real sockets.

**To run tests:** `cargo test --workspace`.
