## Kotlin: no callbacks

A callback is a function-typed parameter, a field or an interface method that project code declares so that
it is invoked after the function that received it has returned, to deliver a result or an event. Not
callbacks: a lambda that runs before the function returns (`Iterable.map { }`, `update { }`,
`withLock(mutex) { }`, `transaction { }`, a builder); a `suspend` block invoked before the function returns
(`withTimeout { }`, `withRetry { }`), inside the caller's structured concurrency; a lambda that a coroutine
builder, a `Flow` operator, a `Modifier` factory or a lifecycle hook (`Lifecycle.Lambda`), the library's or
the project's own, runs inside a job, a collection or a lifecycle the caller owns. Declaring a callback is
adding an `on…: (T) -> Unit` parameter, a `…Listener` or `…Callback` type, or a field of that kind to the
project's own API, outside the two cases under Handlers and outputs.

Project code declares no callback. A result that arrives later is the return value of a `suspend fun`; things
that happen are a `Flow`. A callback exists only at the boundary with a library or platform that offers
nothing else, and is converted there once (The bridge). The two cases that look like callbacks and stay are
named under Handlers and outputs. Existing listener interfaces and existing component outputs stay as they
are, under the Existing code section of the package-layout rule.

### One result later: `suspend fun`

```kotlin
// Bad
fun requestPermission(onResult: (Boolean) -> Unit)
fun loadOffer(onSuccess: (Offer) -> Unit, onFailure: (Throwable) -> Unit)
class RefreshTask(interval: Duration, block: () -> Unit)      // calls block back on a timer

// Good
suspend fun requestPermission(): Boolean
suspend fun loadOffer(): Result<Offer>
scope.launch {
    while (isActive) {
        delay(interval)
        refresh()
    }
}
```

Failure follows the error-handling rule: `Result<T>`, a sealed result when the caller branches on the outcome,
`null` when absence is the only failure.

### Things that happen: `Flow`

- `StateFlow` for state; `SharedFlow` for a broadcast several collectors read, with an explicit
  `extraBufferCapacity` when it is fed through `tryEmit` (`MutableSharedFlow()` with the defaults drops every
  `tryEmit`, and any `SharedFlow` without replay drops a value while nobody collects);
  `Channel(Channel.BUFFERED).receiveAsFlow()` for events one consumer must not lose. Unsubscribing is
  cancelling the collecting job.
- A listener interface of the project, registered with `addListener`/`removeListener` or `subscribe(listener)`,
  is not written. The contract exposes a `Flow` of a sealed event type from `model`, and each subscriber
  collects it in its own scope.

  ```kotlin
  // Bad
  interface TimerListener {
      suspend fun onStarted(config: TimerConfig)
      suspend fun onEnded(cause: TimerEndCause)
  }
  fun addListener(listener: TimerListener)

  // Good: model/TimerEvent.kt, and on the contract
  sealed interface TimerEvent {
      data class Started(val config: TimerConfig) : TimerEvent
      data class Ended(val cause: TimerEndCause) : TimerEvent
  }
  val events: Flow<TimerEvent>
  ```

  A listener interface stays on three triggers only, and the final message names the one that applies: the
  producer must wait until every handler has finished (`SharedFlow.emit` waits at most until every subscriber
  has received the value, never until it has been handled); the handlers must run in a fixed order; the
  producer needs the handler's synchronous result. The third is the platform event that a handler cancels or
  modifies: a `flowEvent` collector receives a Bukkit event after the server's dispatch has returned, and a
  suspending handler can change it only before its first suspension, so such a handler is a plain `Listener`
  in the `event` kind.
- A one-off event from a view model to the UI (show a snackbar, navigate) is a `Channel` read as a flow, never
  a flag in the state that the UI has to clear, and never a `SharedFlow` (without a subscriber it drops the
  event whatever its buffer, with replay it repeats it). The view model sends a neutral event; the UI decides
  what to show. The UI collects inside its lifecycle on `Dispatchers.Main.immediate` (`repeatOnLifecycle` in a
  view, `withContext(Dispatchers.Main.immediate)` inside `LaunchedEffect`) and handles the event at once;
  `BUFFERED` keeps up to 64 events sent while the UI is away; beyond that `trySend` fails.

  ```kotlin
  // Bad
  data class CheckoutState(val total: Money, val showPaidMessage: Boolean)

  // Good
  private val eventChannel = Channel<CheckoutEvent>(Channel.BUFFERED)
  val events: Flow<CheckoutEvent> = eventChannel.receiveAsFlow()

  fun onPaid() {
      eventChannel.trySend(CheckoutEvent.Paid)
  }
  ```

### Handlers and outputs that stay

- The function-typed parameters of a `@Composable` (`onClick: () -> Unit`, `onDismiss`,
  `onValueChange: (String) -> Unit`) are state hoisting (the `compose-hoisting` skill): an event sent up,
  invoked synchronously by the UI when the user acts. They stay and are never replaced by a flow.
- The output of a Decompose component to its parent is one constructor parameter per event, each a
  `fun interface On<Event>Callback` nested in the class of the component whose output it is (beside the
  component's factory, when the project builds components through one), and the parent decides the navigation. Not one `onOutput: (Output) -> Unit`
  with a sealed `Output` and a `when` at the parent, and not a `Flow` of outputs of any kind (`SharedFlow`,
  `Channel.receiveAsFlow()`), which loses the result while the parent is not yet collecting. A stream enters a
  component only as the parent's input or as the component's own UI events.

  ```kotlin
  // Bad
  abstract class CheckoutComponent(componentContext: ComponentContext) : ComponentContext by componentContext {
      fun interface Factory {
          operator fun invoke(componentContext: ComponentContext, onOutput: (CheckoutOutput) -> Unit): CheckoutComponent
      }
  }

  // Good
  abstract class CheckoutComponent(componentContext: ComponentContext) : ComponentContext by componentContext {
      fun interface OnPaidCallback {
          operator fun invoke(order: OrderId)
      }

      fun interface OnCancelledCallback {
          operator fun invoke()
      }

      fun interface Factory {
          operator fun invoke(
              componentContext: ComponentContext,
              onPaidCallback: OnPaidCallback,
              onCancelledCallback: OnCancelledCallback
          ): CheckoutComponent
      }
  }
  ```

### The bridge

- A library callback is converted in the technology package or unit of that library: inside the
  implementation of a contract, or as an extension of the library's own type (`ExoPlayer.asPlaybackStateFlow()`)
  in the `util` of the unit that is wholly that library. The contract in `api` declares only `suspend` functions and `Flow`s; `usecase`,
  `model`, a view model and a composable never see the library's callback or listener type. This is the
  anti-corruption boundary of `arch-context.md`.
- Before writing a bridge, use the adapter that exists: the library's own (`Task.await()`,
  `CompletableFuture.await()`, Firebase `snapshots()`, RevenueCat `awaitCustomerInfo()`) or the project's
  (AstraLibs `flowEvent<T>()` for platform events). The "find the helper that exists" bullet of
  `clean-code.kt.md`.
- **One result:** `suspendCancellableCoroutine`. The callback removes itself before it resumes, so a second
  call cannot resume twice; `invokeOnCancellation` removes it when the caller is cancelled; the continuation
  resumes with the `Result` the contract returns, the library's error translated right there. The bridge never
  throws, and its caller never wraps it in `runCatching`. `suspendCoroutine` is never used: it cannot be
  cancelled. A callback that the library may call again by contract (a billing client's setup listener on every
  reconnect) is a stream, not one result: `callbackFlow` and `first()` at the call. An `isActive` check before
  `resume` only where the listener cannot be removed first.

  ```kotlin
  // consent/acme/AcmeConsentGateway.kt, the technology package of the made-up Acme SDK
  override suspend fun requestConsent(): Result<ConsentStatus> {
      return suspendCancellableCoroutine { continuation ->
          val callback = object : AcmeConsentCallback {
              override fun onResult(status: AcmeConsentStatus) {
                  acme.removeCallback(this)
                  continuation.resume(Result.success(status.toConsentStatus()))
              }

              override fun onError(error: AcmeError) {
                  acme.removeCallback(this)
                  continuation.resume(Result.failure(ConsentRequestError(error.message)))
              }
          }
          continuation.invokeOnCancellation { acme.removeCallback(callback) }
          acme.addCallback(callback)
          acme.requestConsent()
      }
  }
  ```

- **A stream:** `callbackFlow`. Register, `awaitClose { unregister }`, and `trySend(value)` from the callback.
  The producer sets the buffer at the builder: the default, `.buffer(Channel.UNLIMITED)` when no event may be
  lost (`trySend` drops silently when the default 64 slots are full), `.conflate()` when only the latest
  matters. Never `.buffer(Channel.RENDEZVOUS)` or `.buffer(0)`: the producer can deadlock in `awaitClose` under
  flow fusing (kotlinx.coroutines #3459, open), and `trySend` fails whenever the collector is busy. Never
  `trySendBlocking` (JVM only; it blocks the library's thread while the buffer is full, and such a thread never
  wakes after `close()`), never `launch { send(value) }` (order lost, a coroutine per event). An expected
  failure the library reports is a variant of the sealed type the flow carries
  (`PlaybackState.Failed(error: PlaybackError)`, `PlaybackError` from `model`), translated at the bridge; `close(error)` only with a domain error from `model`, for a failure that ends the stream.
  `channelFlow` only when there is nothing to unregister and the producer itself launches several coroutines.
  A bridge that several collectors read is one bridge under `shareIn` with `SharingStarted.WhileSubscribed()`
  (`replay = 1`, or `stateIn`, for a value; `replay = 0` for events), not a registration per collector.

  ```kotlin
  // player/util/ExoPlayerExt.kt, in the unit that is wholly ExoPlayer
  internal fun ExoPlayer.asPlaybackStateFlow(): Flow<PlaybackState> {
      return callbackFlow {
          val listener = object : Player.Listener {
              override fun onPlaybackStateChanged(playbackState: Int) {
                  trySend(playbackState.toPlaybackState())
              }
          }
          addListener(listener)
          awaitClose { removeListener(listener) }
      }.conflate()
  }
  ```

- `CompletableDeferred` only when the answer is completed somewhere other than the request and cannot be one
  `suspendCancellableCoroutine` (a dialog answered by another component). As a replacement for a `suspend fun`,
  or as a readiness flag instead of a `StateFlow`, never.

### Cleanup

| Bridge | Where the listener is removed |
|---|---|
| `callbackFlow` | `awaitClose { unregister }`; it is `try { awaitClose() } finally { }`, and the builder throws without it |
| one result | inside the callback before `resume`, and in `invokeOnCancellation`, which runs only when the caller is cancelled |
| a listener bound to a coroutine, no flow | `register(listener); try { awaitCancellation() } finally { unregister(listener) }` |

- The cleanup lambda of `awaitClose` and `invokeOnCancellation` is plain: a `suspend` call does not compile
  there, and a `launch` on the cancelled scope dies silently. An unregister that itself suspends runs on a
  scope the class owns, `cleanupScope.launch(start = CoroutineStart.ATOMIC) { withContext(NonCancellable) { … } }`,
  under `@OptIn(DelicateCoroutinesApi::class)`. Anywhere else, cleanup that suspends sits only in
  `finally { withContext(NonCancellable) { … } }`.
- The cleanup lambda removes only what this bridge registered, held in a local `val`, and touches no shared
  mutable state: under `flatMapLatest` it runs at every upstream value, concurrently with the next
  registration.
- `CancellationException` is rethrown: after `runCatching`, `propagateCancellationException()` (the
  error-handling rule); in a hand-written `catch`, `catch (e: CancellationException) { throw e }` before the
  broad branch, or `ensureActive()` inside it. detekt's `SuspendFunSwallowedCancellation` and
  `SuspendFunInFinallySection` check this where the project's detekt config enables them.

### Threads

In application code `Thread`, `Executor` and `Executors` (except `asCoroutineDispatcher()` in `core` to build
a dispatcher), Android `Handler.post`, `CompletableFuture` as a return type, `Timer` and `TimerTask` are not
used. `runBlocking` appears only in a `main` function and, inside a technology package, where the platform
demands a blocking callback. A test runs coroutines in `runTest`, never in `runBlocking` (`testing.kt.md`).
