## Testing

When writing a test, make sure that:

* Test domain logic without frameworks: a model rule is called directly in a plain `#[test]`, with no runtime.
* Test use cases with fakes or in-memory implementations of the contracts they call.
* Test technology modules with integration tests where appropriate: against the real technology where it runs
  in a test (a database crate on a temporary database, a file store on a temporary directory, a client and a
  server joined by `tokio::io::duplex` in one process).
* Avoid mocking value objects and simple data structs.
* Prefer fakes over mocks for repositories and gateways when behavior matters.
* Tests should verify expected behavior, not implementation details.
* Do not write tests that simply mirror the current code structure.
* Test names use `given_<state>_when_<action>_then_<outcome>`: the three keywords in lower case, everything
  between them in `snake_case`. Kotlin writes the keywords in upper case; in Rust that is a function name that
  is not snake case, which rustc's `non_snake_case` reports and `-D warnings` turns into an error, so the Rust
  name is all lower case and no lint is suppressed.
* You are testing the expected business logic, not the actual one.
* Prefer splitting code into testable functions if that doesn't affect the public API.
* New code that implements project behaviour MUST have 100% line coverage and 100% branch coverage through
  meaningful behaviour tests. Generated code and trivial field storage are outside this denominator;
  `testing-no-useless.rs.md` describes the distinction. There is no blanket exclusion for `model`, `di` or entry
  points: their own validation, transformations, lifecycle ordering and other project behaviour must be covered.
  Integration tests may cover wiring; a separate test file for every type is not required.
* The aim of the tests is to validate the intended behavior/contract and reveal bugs, not to lock in incidental
  current behavior or implementation details.
* If you're not sure what the business logic of the type is, ask the user.
* Feel free to modify base traits and types to improve their testability, but ask the user first about all
  changes in a base trait or type.
* Tests should cover as many scenarios and edge cases as possible without duplicating existing tests.
* Focus on concurrency and race conditions corner cases. A race needs worker threads:
  `#[tokio::test(flavor = "multi_thread", worker_threads = 2)]`.
* For tests of tasks and channels, `tokio-test` (`task::spawn`, `assert_pending!`, `assert_ready!`) can be used
  if `#[tokio::test]` with paused time is not enough. Otherwise tests can be flaky.
* An async test is an `async fn` under `#[tokio::test]`, never a runtime the test builds or blocks on
  (`Runtime::block_on`, `Handle::block_on`, `futures::executor::block_on`). A test that waits on time uses
  `#[tokio::test(start_paused = true)]`: the runtime moves the clock forward whenever every task is idle, so a
  one-hour `sleep` returns at once. Paused time needs tokio's `test-util` feature in `[dev-dependencies]` and the
  default `current_thread` flavor.
* `#[tokio::test]` reports neither a task that outlives the test nor a panic inside a task: when the test returns,
  the runtime drops every task still running, and a panic in a task reaches only its `JoinHandle`. A test awaits
  the `JoinHandle` of every task it starts, or stops the code under test through its own shutdown and awaits
  that.

Example:

```rust
// test/order/usecase/create_order_use_case_test.rs
use crate::order::model::{CreateOrderCommand, CreateOrderResult, CustomerId};
use crate::order::usecase::CreateOrderUseCase;
use crate::test::order::fake::FakeOrderRepository;
use crate::test::payment::fake::FakePaymentGateway;
use std::sync::Arc;

#[tokio::test]
async fn given_empty_cart_when_order_is_created_then_returns_cart_is_empty() {
    let create_order_use_case = CreateOrderUseCase::new(
        Arc::new(FakeOrderRepository::new()),
        Arc::new(FakePaymentGateway::new()),
    );

    let result = create_order_use_case
        .invoke(CreateOrderCommand {
            customer_id: CustomerId(1),
            items: Vec::new(),
        })
        .await;

    assert_eq!(CreateOrderResult::CartIsEmpty, result);
}
```

Good test focus:

```rust
#[tokio::test]
async fn given_existing_active_customer_when_order_is_created_then_order_is_saved()
```

Bad test focus:

```rust
#[tokio::test]
async fn given_create_order_when_invoke_called_then_repository_save_called_once()
```

The second test verifies an implementation detail. The first verifies the expected behavior of the use case.

Example fake:

```rust
// test/user/fake/fake_user_repository.rs
pub(crate) struct FakeUserRepository {
    users: Mutex<HashMap<UserId, User>>,
    saved: Mutex<Vec<User>>,
}

impl FakeUserRepository {
    pub(crate) fn new() -> Self {
        Self {
            users: Mutex::new(HashMap::new()),
            saved: Mutex::new(Vec::new()),
        }
    }

    pub(crate) fn saved(&self) -> Vec<User> {
        self.saved.lock().clone()
    }
}

#[async_trait]
impl UserRepository for FakeUserRepository {
    async fn find_by_id(&self, id: UserId) -> Option<User> {
        self.users.lock().get(&id).cloned()
    }

    async fn save(&self, user: User) -> SaveUserResult {
        self.users.lock().insert(user.id, user.clone());
        self.saved.lock().push(user);
        SaveUserResult::Success
    }
}
```

The fake's locks are `parking_lot::Mutex`, as every lock no `.await` crosses (`async.rs.md`, Shared state and
locks).

### Where tests live

* Each crate has a `test/` directory beside `src/`, and `test/` mirrors `src/` directory for directory:
  `src/order/usecase/create_order_use_case.rs` is tested by `test/order/usecase/create_order_use_case_test.rs`. A
  test file is named after the file of the owner of the behaviour it checks (a use case, a repository
  implementation, a model rule, an entry point), with `_test`; a type with no behaviour of its own gets no test
  file.
* The test tree is declared once, as the last item of the crate's root file (`src/lib.rs`, or `src/main.rs` in a
  binary crate), with nested blocks exactly like the source tree. Its `#[path = "../test"]` and the fixture
  block's `#[path = "../fixture"]` are the only `#[path]`s of the crate, the test block is private, and `src/`
  holds no other `#[cfg(test)]` item.

  ```rust
  #[cfg(test)]
  #[path = "../test"]
  mod test {
      mod order {
          pub(crate) mod fake {
              pub(crate) use fake_order_repository::FakeOrderRepository;
              mod fake_order_repository;
          }
          mod usecase {
              mod create_order_use_case_test;
          }
      }
  }
  ```

* The test tree is part of the crate: it sees `pub(crate)`, the analog of Kotlin `internal`, and imports through
  the kind modules (`use crate::order::usecase::CreateOrderUseCase;`). Nothing in `src/` is widened for a test: a
  private function is tested through the item that calls it.
* A same-crate fake lives in `fake/` inside the concept of the trait it replaces, in the test tree:
  `test/order/fake/fake_order_repository.rs` fakes `crate::order::api::OrderRepository`. It is `pub(crate)`, and
  the `fake` block re-exports it with `pub(crate) use`; tests import it as
  `use crate::test::order::fake::FakeOrderRepository;`. A test that reads a fake after handing it to the code
  under test keeps it in an `Arc` and passes `fake_order_repository.clone()`: `Arc::clone(&fake_order_repository)`
  takes its type from the `Arc<dyn OrderRepository>` parameter and does not compile (E0308).
* A fake scripts failures or records calls; a double that only stores values in memory is an in-memory
  implementation, `InMemory<Trait>` in the `memory` module of the concept: in `src/` when production code or
  another crate uses it, and in the test tree (`test/order/memory/in_memory_order_repository.rs`) when only the
  crate's own tests construct it, because an item only tests use is dead code in the crate's normal build, and
  `dead_code` under `-D warnings` stops it.
* A fake that tests of other crates need lives in the fixture tree of the crate that owns the trait, Kotlin's
  `testFixtures` source set: `fixture/order/fake/fake_order_repository.rs` beside `src/` and `test/`, `pub`,
  compiled under `#[cfg(any(test, feature = "fake"))]`, and never copied into each consumer. The crate's own tests
  use it as `crate::fixture::order::fake::FakeOrderRepository`; another crate enables the `fake` feature only in
  its `[dev-dependencies]`, never in `[dependencies]`, and uses it from its test tree. The Rust package-layout rule
  gives the Cargo setup.
* There is no `tests/` directory: the tests of the wired application sit in the entry-point crate's test tree,
  and a published crate's public API is reached from its test tree through `crate::` paths, and from outside by
  its `# Examples` doctests (`rustdoc.rs.md`). A procedural-macro crate tests its helper code in its `test/` tree
  like any crate. Only the tests that expand its macros are the exception, since a macro cannot be used in the
  crate that defines it: they are one integration-test crate, `tests/it/main.rs`, whose nested blocks mirror
  `src/` the same way (`tests/it/order/derive_order_test.rs`).

**Frameworks**: the built-in `#[test]` harness, `#[tokio::test]` with tokio's `test-util` feature in
`[dev-dependencies]`.

**To run tests:** `cargo test --workspace`
