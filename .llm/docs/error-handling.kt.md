## Kotlin: Error Handling — `Result`

### Choosing the failure type

| Situation                                                                               | Use                             |
|-----------------------------------------------------------------------------------------|---------------------------------|
| Absence is the only meaningful failure                                                  | nullable type                   |
| Caller needs to know that it failed and why, but does not branch on the kind of failure | `Result<T>`                     |
| Caller must handle several outcomes differently                                         | per-use-case `sealed interface` |
| Programmer error or broken invariant (`require`, `check`, unreachable branch)           | throw                           |

Never throw for an expected business or validation failure. Throwing is reserved for bugs.

### Contract

A function that can fail returns `Result<T>`. Kotlin's `Result` has a single type parameter, so the
failure is always a `Throwable`. Model domain errors as a sealed hierarchy of exception classes. They
are a payload for `Result.failure`; your own code never throws them.

```kotlin
sealed class OrderError(message: String, cause: Throwable?) : Exception(message, cause)

class OrderParseError(message: String) : OrderError(message, null)
class OrderValidationError(message: String) : OrderError(message, null)
class OrderLoadError(message: String, cause: Throwable) : OrderError(message, cause)
```

```kotlin
fun parseOrder(raw: String): Result<Order> {
    if (raw.isBlank()) {
        return Result.failure(OrderParseError("Order payload is blank"))
    }
    return Result.success(Order(/* ... */))
}

fun validateOrder(order: Order): Result<Order> {
    if (order.items.isEmpty()) {
        return Result.failure(OrderValidationError("Order must contain at least one item"))
    }
    return Result.success(order)
}
```

### Boundaries: converting exceptions

`runCatching` is allowed only around code you do not own that throws: third-party clients, I/O,
serialization. Translate the caught exception into a domain error right there, so inner layers never
see library exceptions.

```kotlin
fun loadOrder(id: OrderId): Result<Order> =
    runCatching { thirdPartyClient.fetchOrder(id.value).toDomain() }
        .fold(
            onSuccess = { order -> Result.success(order) },
            onFailure = { error ->
                Result.failure(OrderLoadError("Could not load order ${id.value}", error))
            }
        )
```

`mapCatching` and `recoverCatching` are boundary tools in the same sense: use them only when the
transformation or the fallback calls code you do not own that throws.

Do not wrap your own logic in `runCatching`, `mapCatching` or `recoverCatching`. If your code needs
them, it is throwing where it should return `Result.failure`. Never `throw` inside these blocks to
re-label an error; use `fold` as above.

### Coroutines

`runCatching` catches `CancellationException` and breaks structured concurrency. In `suspend` code
rethrow it before doing anything else with the result:

```kotlin
suspend fun loadOrder(id: OrderId): Result<Order> =
    runCatching { thirdPartyClient.fetchOrder(id.value).toDomain() }
        .onFailure { error -> if (error is CancellationException) throw error }
        .fold(
            onSuccess = { order -> Result.success(order) },
            onFailure = { error ->
                Result.failure(OrderLoadError("Could not load order ${id.value}", error))
            }
        )
```

### Composing fallible steps

`Result` has no `flatMap`. Chain steps with `getOrElse` and an early return; the happy path stays
flat and nothing is thrown.

```kotlin
fun orderTotal(raw: String): Result<Money> {
    val order = parseOrder(raw).getOrElse { error -> return Result.failure(error) }
    val validOrder = validateOrder(order).getOrElse { error -> return Result.failure(error) }
    return Result.success(validOrder.total)
}
```

Use `map` for a pure transformation of the success value and `recover` for a fallback value:

```kotlin
val total: Result<Money> = parseOrder(raw).map { order -> order.total }

val totalOrZero: Result<Money> = total.recover { _ -> Money.zero() }
```

### Consuming a `Result`

Use `fold` when you need one final value, and `onSuccess`/`onFailure` for side effects such as
logging:

```kotlin
val response: HttpResponse = result.fold(
    onSuccess = { order -> HttpResponse.ok(order) },
    onFailure = { error -> HttpResponse.badRequest(error.message ?: "Invalid order") }
)

result
    .onSuccess { order -> logger.info("Loaded order ${order.id}") }
    .onFailure { error -> logger.warn("Could not load order", error) }
```

`getOrThrow` is allowed only where throwing is the intended contract: tests, startup validation, or
integration with an API that requires exceptions. Never use it to skip handling a failure.

Log a failure once, at the call site that has enough context. Do not log and rethrow, and do not
discard a `Result` without consuming it.
