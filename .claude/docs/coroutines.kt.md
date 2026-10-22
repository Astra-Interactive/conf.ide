## Kotlin: coroutines

- A `StateFlow` always holds a value. Read it with `.value`, or with `first()` in `suspend` code, never
  inside `withTimeout` or `withTimeoutOrNull`: the read cannot wait, so the timeout never fires and only
  hides what the code does. A timeout wraps a call that can actually wait: a network call, a `SharedFlow`
  without replay, `first { predicate }` on a flow whose current value may not match.

  ```kotlin
  // Bad
  val content = withTimeoutOrNull(1.seconds) { state.first() }

  // Good
  val content = state.value
  ```
