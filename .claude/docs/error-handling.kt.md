## Kotlin: Error Handling — `Result`

### Choosing the failure type

| Situation                                                                               | Use                             |
|-----------------------------------------------------------------------------------------|---------------------------------|
| Absence is the only meaningful failure                                                  | nullable type                   |
| Caller needs to know that it failed and why, but does not branch on the kind of failure | `Result<T>`                     |
| Caller must handle several outcomes differently                                         | per-use-case `sealed interface` |
| Programmer error or broken invariant (`require`, `check`, unreachable branch)           | throw                           |

Never throw for an expected business or validation failure. Throwing is reserved for bugs, with one
exception: a framework that takes a failure only as a thrown exception (a command framework's
`CommandException`). There the exception extends the framework's type, lives in `model`, is thrown only
inside that framework's entry point (`command`), and the handler that turns it into a reply lives in `error`.

### Contract

A function that can fail returns `Result<T>`. Kotlin's `Result` has a single type parameter, so the
failure is always a `Throwable`. Model domain errors as a sealed hierarchy of exception classes. They
are a payload for `Result.failure`; your own code never throws them.

```kotlin
// model/OrderError.kt: the sealed class and every subclass, one file
sealed class OrderError(message: String, cause: Throwable?) : Exception(message, cause)

class OrderParseError(message: String) : OrderError(message, null)
class OrderValidationError(message: String) : OrderError(message, null)
class OrderLoadError(message: String, cause: Throwable) : OrderError(message, cause)
```

```kotlin
fun parseOrder(raw: String): Result<Order> {
    if (raw.isBlank()) return Result.failure(OrderParseError("Order payload is blank"))
    return Result.success(Order(/* ... */))
}

fun Order.validate(): Result<Order> {
    if (items.isEmpty()) return Result.failure(OrderValidationError("Order must contain at least one item"))
    return Result.success(this)
}
```

### Where error types live

- An error type that a contract's signature names, or that its implementations return in `Result.failure`,
  lives in the `model/` package of that contract's level, in one file with its whole hierarchy:
  `model/OrderError.kt` holds `OrderError` and every subclass.
- A per-use-case sealed result (`CreateOrderResult`) lives in the same `model/`, with its failure variants
  nested next to the success ones.
- Any other error type, or error hierarchy with its subclasses, is its own file in the `model/` of the level
  that uses it, even one that never leaves one class, never a private class inside the file that returns or
  throws it.
- An old `exception/` package stays as it is; new error types of its concept still go to `model/`.

### Boundaries: converting exceptions

`runCatching` is allowed only around code you do not own that throws: third-party clients, I/O,
serialization. Translate the caught exception into a domain error right there, so inner layers never
see library exceptions.

```kotlin
import kotlin.Result.Companion.success

fun fetchOrder(id: OrderId): Result<Order> {
    return runCatching { thirdPartyClient.fetchOrder(id.value).toOrder() }
        .fold(
            onSuccess = ::success,
            onFailure = { error ->
                Result.failure(OrderLoadError("Could not load order ${id.value}", error))
            }
        )
}
```

`mapCatching` and `recoverCatching` are boundary tools in the same sense: use them only when the
transformation or the fallback calls code you do not own that throws.

Do not wrap your own logic in `runCatching`, `mapCatching` or `recoverCatching`. If your code needs
them, it is throwing where it should return `Result.failure`. Never `throw` inside these blocks to
re-label an error; use `fold` as above.

### Coroutines

`runCatching` catches `CancellationException` and breaks structured concurrency. In `suspend` code
rethrow it before doing anything else with the result, through mikro-core's
`Result<T>.propagateCancellationException()` (`ru.astrainteractive.klibs.mikro.core.coroutines`):

```kotlin
import ru.astrainteractive.klibs.mikro.core.coroutines.propagateCancellationException
import kotlin.Result.Companion.success

suspend fun fetchOrder(id: OrderId): Result<Order> {
    return runCatching { thirdPartyClient.fetchOrder(id.value).toOrder() }
        .propagateCancellationException()
        .fold(
            onSuccess = ::success,
            onFailure = { error ->
                Result.failure(OrderLoadError("Could not load order ${id.value}", error))
            }
        )
}
```

When mikro-core is in the project's version catalog but the unit does not depend on it yet, add the
catalog's mikro-core alias to the unit's dependencies: the version is already the project's choice. Only in
a project with no mikro in its version catalog is the check written inline, and then as
`.onFailure { error -> if (error is CancellationException) throw error }` right after `runCatching`.

### Composing fallible steps

`Result` has no `flatMap`. Chain steps with `getOrElse` and an early return; the happy path stays
flat and nothing is thrown.

```kotlin
fun computeOrderTotal(raw: String): Result<Money> {
    val order = parseOrder(raw).getOrElse { error -> return Result.failure(error) }
    val validOrder = order.validate().getOrElse { error -> return Result.failure(error) }
    return Result.success(validOrder.total)
}
```

Use `map` for a pure transformation of the success value and `recover` for a fallback value:

```kotlin
val total: Result<Money> = parseOrder(raw).map(Order::total)

val totalOrZero: Result<Money> = total.recover { _ -> Money.ZERO }
```

### Consuming a `Result`

Use `fold` when you need one final value, and `onSuccess`/`onFailure` for side effects such as
logging:

```kotlin
val response: HttpResponse = result.fold(
    onSuccess = HttpResponse::ok,
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
