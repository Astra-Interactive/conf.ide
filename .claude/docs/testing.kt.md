## Testing

When writing a test, make sure that:

* Test domain logic without frameworks.
* Test use cases with fakes or in-memory implementations of the contracts they call.
* Test technology packages with integration tests where appropriate.
* Avoid mocking value objects and simple data classes.
* Prefer fakes over mocks for repositories and gateways when behavior matters.
* Tests should verify expected behavior, not implementation details.
* Do not write tests that simply mirror the current code structure.
* Test names use `GIVEN_<state>_WHEN_<action>_THEN_<outcome>`: the three keywords in upper case, everything between them in `snake_case`.
* These names break detekt's `FunctionNaming` rule on purpose. Suppress it once per test file with `@file:Suppress("FunctionNaming")` at the top of the file; never rename the tests to satisfy the linter and never disable the rule in the detekt config.
* You are testing the expected business logic, not the actual one.
* Prefer splitting code into testable functions/chunks if that doesn't affect the public API.
* New code MUST be covered by tests at 100%. The coverage comes from behaviour tests as described here; the testing-no-useless rule does not lower this bar, it only forbids tests that exercise the language or a framework instead of project logic.
* The aim of the tests is to validate the intended behavior/contract and reveal bugs, not to lock in incidental current behavior or implementation details.
* If you're not sure what the business logic of the class is, ask the user.
* Feel free to modify base classes to improve their testability, but ask the user first about all changes in base class.
* Tests should cover as many scenarios and edge cases as possible without duplicating existing tests.
* Focus on multithreading and race conditions corner cases.
* For tests involving coroutines/reactivity, `cashapp/turbine` can be used, if `kotlinx.coroutines.test` is not enough. Otherwise tests can be flaky.
* A coroutine test runs in `runTest` from `kotlinx.coroutines.test`, never in `runBlocking`: `runTest` skips `delay` and reports coroutines that leak from the test.

Example:

```kotlin
@file:Suppress("FunctionNaming")

package com.example.order

@Test
fun GIVEN_empty_cart_WHEN_order_is_created_THEN_returns_cart_is_empty() {
    val createOrderUseCase = CreateOrderUseCase(
        orderRepository = FakeOrderRepository(),
        paymentGateway = FakePaymentGateway()
    )

    val result = createOrderUseCase.invoke(
        CreateOrderCommand(
            customerId = CustomerId("customer-1"),
            items = emptyList()
        )
    )

    assertEquals(CreateOrderResult.CartIsEmpty, result)
}
```

Good test focus:

```kotlin
@Test
fun GIVEN_existing_active_customer_WHEN_order_is_created_THEN_order_is_saved()
```

Bad test focus:

```kotlin
@Test
fun GIVEN_create_order_WHEN_execute_called_THEN_repository_save_called_once()
```

The second test verifies implementation detail. The first verifies the expected behavior of the use case.

Example fake:

```kotlin
internal class FakeUserRepository : UserRepository {
    private val users = mutableMapOf<UserId, User>()
    val saved = mutableListOf<User>()

    override suspend fun findById(id: UserId): User? {
        return users[id]
    }

    override suspend fun save(user: User): SaveUserResult {
        users[user.id] = user
        saved += user
        return SaveUserResult.Success
    }
}
```

### Where tests live

* `src/test/kotlin` mirrors `src/main/kotlin` package for package: `…data.exposed.rating.ExposedRatingRepository` is tested by `src/test/kotlin/…/data/exposed/rating/ExposedRatingRepositoryTest.kt`. In Kotlin Multiplatform, `commonTest` mirrors `commonMain`.
* A fake lives in `fake/` inside the concept of the contract it replaces, in the test tree: `src/test/kotlin/…/data/dao/rating/fake/FakeRatingRepository.kt` fakes `…data.dao.rating.api.RatingRepository`. A fake scripts failures or records calls; a double that only stores values in memory is an in-memory implementation and lives in production code in a `memory` technology package.
* A fake that tests of other build units need lives in the `testFixtures` source set of the unit that owns the contract, at the same path, and is never copied into each consumer. The Kotlin package-layout rule gives the Gradle setup and the Kotlin Multiplatform alternative.

**Frameworks**: `kotlin.test`, `kotlinx.coroutines.test`

**To run tests on kotlin-jvm:** `./gradlew test`
**To run tests on kotlin-multiplatform:** `./gradlew allTests`
