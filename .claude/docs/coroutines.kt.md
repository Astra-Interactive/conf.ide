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

- Writing a `MutableStateFlow`: `update { current -> ... }` when the new value depends on the current one;
  `.value =` when it does not. `emit` and `tryEmit` are never called on a `MutableStateFlow`, in `suspend`
  code included: on a `StateFlow` they are the setter under a name that promises a suspension or
  back-pressure that does not exist (`emit` never suspends there, `tryEmit` always returns `true`). They
  belong to `SharedFlow`.

  ```kotlin
  state.update { current -> current.copy(isBusy = false) }   // depends on the current value
  state.value = SplashPaywallState.Finished                   // does not
  state.emit(SplashPaywallState.Finished)                     // never
  ```

- The lambda of `update`, `getAndUpdate` and `updateAndGet` is pure: it is a compare-and-set loop, so the
  lambda may run twice, and it cannot suspend. A `var` captured in it to carry a result out is forbidden.
  To know what was stored, call `getAndUpdate` and apply the same pure transition to the previous value
  again; the transition itself is an extension in `util`. `updateAndGet` returns the new value but cannot
  say whether it changed, and `compareAndSet` returns `true` without changing anything when the new value
  equals the current one.

  ```kotlin
  // Bad
  private fun startBusyOffer(): SplashPaywallState.Content? {
      var started: SplashPaywallState.Content? = null
      state.update { current ->
          val content = current as? SplashPaywallState.Content ?: return@update current
          content.copy(isBusy = true).also { busy -> started = busy }
      }
      return started
  }

  // Good: splash/util/SplashPaywallStateExt.kt, the pure transition
  internal fun SplashPaywallState.startBusyOffer(): SplashPaywallState.Content? {
      if (this !is SplashPaywallState.Content) {
          return null
      }
      val isOfferShown = stage == SplashPaywallStage.OFFER
      if (!isOfferShown || isBusy) {
          return null
      }
      return copy(isBusy = true)
  }

  // Good: the view model
  private fun claimBusyOffer(): SplashPaywallState.Content? {
      val previous = state.getAndUpdate { current -> current.startBusyOffer() ?: current }
      return previous.startBusyOffer()
  }
  ```

- A coroutine launched from a user action is guarded atomically against a second launch; a flag in the
  state such as `isBusy` is what the UI shows, not a lock: two fast clicks both read `false`. In order:
  1. the project's single-job scope when its library has one (`viewModelScope.asSingleJobScope()`; the mode
     is passed to every `launch`, never left to the default: skip while running for a purchase, cancel the
     previous for a search). A scope derived from the class's own lifecycle scope is not a dependency to
     inject; the DI rule on constructors does not apply to it;
  2. otherwise a compare-and-set on the state through `getAndUpdate` with a pure transition, as above: the
     guard and the `isBusy` display are one write;
  3. as the fallback `Mutex.withLock {}`, which queues the second click instead of skipping it, so the block
     re-checks the state before acting.

  ```kotlin
  // Bad: a second click launches a second purchase
  fun onPurchase() {
      viewModelScope.launch { offerRepository.purchase(plan) }
  }

  // Good
  private val purchaseScope = viewModelScope.asSingleJobScope()

  fun onPurchase() {
      purchaseScope.launch(SingleJobMode.SKIP_IF_RUNNING) { offerRepository.purchase(plan) }
  }
  ```
