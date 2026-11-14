## Rust: no callbacks

A callback is a parameter or a field of a closure type (`impl Fn…`, `Box<dyn Fn…>`, a type parameter bounded by
`Fn`, `FnMut` or `FnOnce`), or a trait method, that project code declares so that it is invoked after the
function that received it has returned, to deliver a result or an event. Not callbacks: a closure that runs
before the function returns (`Iterator::map`, `Option::map_or_else`, `send_modify`, `fetch_update`, a builder);
an `async` block awaited before the function returns (`timeout(duration, async { … })`); a closure or a future
that a `TaskScope`, a runtime or a stream combinator runs inside a scope, a task or a stream the caller owns.
Declaring a callback is adding an `on_…` parameter of a closure type, a `…Listener` or `…Callback` trait, or a
field of that kind to the project's own API. The one allowed exception is a listener trait that meets one of the
three triggers under Things that happen; a type in the `event` kind that implements the platform's own listener
trait declares no callback. A checker flags every `on_…` parameter of a closure type and every `…Listener` and
`…Callback` trait outside the platform listener impls of `event`; the reviewer clears one that runs before the
function returns or meets a documented listener trigger. The checker judges a field of a closure type in a struct
and in an enum variant alike. It does not flag a closure inside a container field (`Vec<Box<dyn Fn…>>`,
`HashMap<…, Box<dyn Fn…>>`): by its type a listener registry cannot be told from a table of functions that run
before the function returns, so that field stays with the reviewer. A trigger must be named, as required below.

Outside that exception, project code declares no callback. A result that arrives later is the return value of an
`async fn`; state is a `watch` channel; things that happen are a stream. A library or platform callback is
converted once at its boundary (The bridge); handlers that require synchronous platform dispatch keep the
listener form described below. Existing listener traits stay as they are, under the Existing code section of the
package-layout rule.

### One result later: `async fn`

```rust
// Bad
fn request_permission(&self, on_result: Box<dyn FnOnce(bool) + Send>);
fn load_offer(&self, on_success: Box<dyn FnOnce(Offer) + Send>, on_failure: Box<dyn FnOnce(OfferError) + Send>);
struct RefreshTask { interval: Duration, block: Box<dyn Fn() + Send + Sync> } // calls block back on a timer

// Good
async fn request_permission(&self) -> bool;
async fn load_offer(&self) -> Result<Offer, OfferError>;
self.task_scope.spawn(async move {
    let mut ticks = tokio::time::interval(interval);
    loop {
        ticks.tick().await;
        offer_cache.refresh().await;
    }
});
```

Failure follows the error-handling rule: `Result<T, E>`, a per-use-case enum when the caller branches on the
outcome, `Option` when absence is the only failure.

### Things that happen: `watch` and streams

- `watch` for state: the holder keeps the `watch::Sender`, a reader gets a `watch::Receiver` (`borrow()` for the
  value, `changed()` to wait for the next one), and the write rules are in `async.rs.md`. Events reach a
  subscriber as a stream of a model enum, `BoxStream<'static, Event>` (`arch-domain.rs.md`). Behind it:
  - a `broadcast` channel for an event several subscribers read. Its capacity is a required argument; `send` fails
    and drops the event while nobody is subscribed; a subscriber that falls behind by more than the capacity
    receives `RecvError::Lagged(n)` and has skipped `n` events;
  - an `mpsc` channel with an explicit capacity for events one consumer must not lose.

  Unsubscribing is dropping the stream or the receiver.
- A loop over a `broadcast::Receiver` matches `Lagged` and goes on. `while let Ok(event) = receiver.recv().await`
  ends at the first lag, with events still in the channel.

  ```rust
  // timer/memory/in_memory_timer.rs: the stream behind the contract
  fn events(&self) -> BoxStream<'static, TimerEvent> {
      stream::unfold(self.events.subscribe(), |mut receiver| async move {
          loop {
              match receiver.recv().await {
                  Ok(event) => return Some((event, receiver)),
                  Err(RecvError::Lagged(_)) => continue,
                  Err(RecvError::Closed) => return None,
              }
          }
      })
      .boxed()
  }
  ```

- A listener trait of the project, registered with `add_listener`/`remove_listener` or `subscribe(listener)`, is
  not written unless one of the three listener triggers below holds. Otherwise the contract hands out a stream of
  an event enum from `model`, and each subscriber reads it in its own task.

  ```rust
  // Bad
  pub(crate) trait TimerListener: Send + Sync {
      fn on_started(&self, config: &TimerConfig);
      fn on_ended(&self, cause: TimerEndCause);
  }
  fn add_listener(&self, listener: Arc<dyn TimerListener>);

  // Good: timer/model/timer_event.rs, and on the contract
  pub(crate) enum TimerEvent {
      Started { config: TimerConfig },
      Ended { cause: TimerEndCause },
  }
  fn events(&self) -> BoxStream<'static, TimerEvent>;
  ```

  A listener trait stays on three triggers only, and the final message names the one that applies: the producer
  must wait until every handler has finished (`broadcast::Sender::send` returns at once and never waits for a
  subscriber, let alone a handler); the handlers must run in a fixed order; the producer needs the handler's
  synchronous result. The third is the platform event that a handler cancels or modifies: the host reads the
  event again as soon as its dispatch returns, and a stream subscriber receives it only later, so such a handler
  is a plain implementation of the host's listener trait in the `event` kind. Whether a trigger holds is the
  reviewer's call; the trigger named in the final message is what the reviewer checks.
- A one-off event from a state holder to the one consumer that acts on it (show a message, close a connection) is
  an `mpsc` channel, never a flag in the state that the consumer has to clear, and never a `broadcast`, which drops
  the event while nobody is subscribed. The holder sends a neutral event; the consumer decides what to do. Kotlin's
  view model creates its `Channel` and hands out `receiveAsFlow()`; an `mpsc::Receiver` has one owner and is not
  `Clone`, so the DI module, which builds both the holder and the consumer, creates the channel and gives the
  `Sender` to the holder and the `Receiver` to the consumer, which reads it in its own task and handles each event
  at once. The holder sends with `try_send`, as Kotlin's view model calls `trySend`: a bounded channel keeps up to
  its capacity of events while the consumer is busy, and beyond that the event is dropped (`TrySendError::Full`),
  under the channel-send exception of `error-handling.rs.md`.

  ```rust
  // Bad
  pub(crate) struct CheckoutState {
      pub(crate) total: Money,
      pub(crate) show_paid_message: bool,
  }

  // Good
  pub(crate) fn on_paid(&self) {
      #[expect(
          clippy::let_underscore_must_use,
          reason = "a full buffer drops the event, as Kotlin's trySend does; a gone consumer has stopped"
      )]
      let _ = self.events.try_send(CheckoutEvent::Paid);
  }
  ```

### The bridge

- A library callback is converted in the technology module of that library, inside the implementation of a
  contract. The contract in `api` declares only `async fn`s, `watch::Receiver`s and streams; `usecase`, `model`
  and the entry points never see the library's callback or listener type. This is the anti-corruption boundary of
  `arch-context.md`.
- Before writing a bridge, use the adapter that exists: the library's own `async` API or stream, or the project's
  (the "find the helper that exists" bullet of `clean-code.rs.md`).
- **One result:** a `oneshot` channel. The callback sends on the `oneshot::Sender`, and `send` consumes the
  sender, so a second call cannot complete the request twice (a callback typed `Fn` keeps the sender in a
  `parking_lot::Mutex<Option<…>>` and `take()`s it). A registration guard bound to a named variable
  (`_registration`; `let _ =` would drop it at once) removes the callback in its `Drop`, both when the result
  arrives and when the caller drops the future. The `async fn` returns the `Result` the contract names, the library's error translated right
  there. A callback that the library may call again by contract is a stream, not one result.

  ```rust
  // consent/acme/acme_consent_gateway.rs, the technology module of the made-up Acme SDK
  async fn request_consent(&self) -> Result<ConsentStatus, ConsentError> {
      let (sender, receiver) = oneshot::channel();
      let callback_id = self.acme.add_consent_callback(Box::new(move |outcome| {
          #[expect(
              clippy::let_underscore_must_use,
              reason = "the receiver is gone only when the caller was cancelled"
          )]
          let _ = sender.send(outcome);
      }));
      let _registration = AcmeCallbackRegistration::new(Arc::clone(&self.acme), callback_id);
      self.acme.request_consent();
      match receiver.await {
          Ok(Ok(status)) => Ok(ConsentStatus::from(status)),
          Ok(Err(error)) => Err(ConsentError::Rejected {
              reason: error.message,
          }),
          Err(_) => Err(ConsentError::Abandoned),
      }
  }

  // consent/acme/acme_callback_registration.rs
  impl Drop for AcmeCallbackRegistration {
      fn drop(&mut self) {
          self.acme.remove_consent_callback(self.callback_id);
      }
  }
  ```

- **A stream:** the bridge registers with the library when the first subscriber arrives and unregisters when the
  last one leaves, Kotlin's `shareIn` with `SharingStarted.WhileSubscribed()`, and every subscriber reads one
  channel the bridge owns, never a registration per subscriber. The bridge keeps the registration as a
  `parking_lot::Mutex<Weak<…Registration>>`; a subscription upgrades it or registers anew, and its stream holds the
  `Arc<…Registration>`, whose `Drop` unregisters, so dropping the last stream unregisters. A subscriber that
  arrives while the last guard is being dropped registers a second time for a moment; each guard removes only its
  own listener (Cleanup). The channel sets the buffer and stays with the bridge across registrations:
  `watch::Sender::send_replace` when only the latest value matters (Kotlin's `conflate()`, and a new subscriber
  reads the last value, as with `stateIn`); `broadcast::Sender::send` for events several subscribers read;
  `mpsc::Sender::try_send` into a bounded channel for one consumer, which drops the event when the buffer is full,
  or `mpsc::UnboundedSender::send` when no event may be lost. The last three are the channel-send exception of
  `error-handling.rs.md`. Never `blocking_send` in a library's callback (it blocks the library's thread while the
  buffer is full, and panics when the callback runs on a runtime thread), never `tokio::spawn` per event (order
  lost, a task per event). An expected failure the library reports is a variant of the enum the channel carries
  (`PlaybackState::Failed { error: PlaybackError }`, `PlaybackError` from `model`), translated at the bridge.

  ```rust
  // player/acme/acme_playback_bridge.rs, the technology module of the made-up Acme SDK
  pub(crate) struct AcmePlaybackBridge {
      player: Arc<AcmePlayer>,
      state: Arc<watch::Sender<PlaybackState>>,
      registration: Mutex<Weak<AcmeListenerRegistration>>,
  }

  impl AcmePlaybackBridge {
      pub(crate) fn new(player: Arc<AcmePlayer>) -> Self {
          let (state, _) = watch::channel(PlaybackState::Idle);
          Self {
              player,
              state: Arc::new(state),
              registration: Mutex::new(Weak::new()),
          }
      }

      fn acquire_registration(&self) -> Arc<AcmeListenerRegistration> {
          let mut registration = self.registration.lock();
          if let Some(active) = registration.upgrade() {
              return active;
          }
          let state = Arc::clone(&self.state);
          let listener_id = self.player.add_state_listener(Box::new(move |raw_state| {
              state.send_replace(PlaybackState::from(raw_state));
          }));
          let active = Arc::new(AcmeListenerRegistration::new(
              Arc::clone(&self.player),
              listener_id,
          ));
          *registration = Arc::downgrade(&active);
          active
      }
  }

  impl PlaybackStatePublisher for AcmePlaybackBridge {
      fn state(&self) -> BoxStream<'static, PlaybackState> {
          let registration = self.acquire_registration();
          let mut receiver = self.state.subscribe();
          receiver.mark_changed();
          stream::unfold(
              (receiver, registration),
              |(mut receiver, registration)| async move {
                  if receiver.changed().await.is_err() {
                      return None;
                  }
                  let state = receiver.borrow_and_update().clone();
                  Some((state, (receiver, registration)))
              },
          )
          .boxed()
      }
  }
  ```

- A `oneshot` handed to someone else only when the answer is completed somewhere other than the request and
  cannot be one bridge (a confirmation another component answers). As a replacement for an `async fn`, or as a
  readiness flag instead of a `watch`, never.

### Cleanup

| Bridge | Where the callback is removed |
|---|---|
| one result | a guard local to the `async fn`: its `Drop` runs when the result arrives and when the caller drops the future |
| a stream | a guard every subscriber's stream shares through an `Arc`: its `Drop` runs when the last stream is dropped |
| a listener bound to a task, no channel | a guard local to the task: aborting the task drops it |

- `Drop` is synchronous and short: an async drop is unstable (E0658 on stable), and a destructor that may block
  needs a separate teardown method (API Guidelines, C-DTOR-BLOCK). An unregister that is itself `async` is either
  an `async fn close(self)` that the owner awaits before it drops the bridge, or, where the guard of a one-result
  bridge may be dropped by cancellation, a task the guard hands to the `TaskScope` of the gateway that owns it
  (`async.rs.md`, Tasks). `TaskScope::spawn` only sends on a channel, so it works in a `Drop` that runs outside the
  runtime, where `tokio::spawn` panics.
- The guard removes only what this bridge registered, held in its own field, and touches no shared mutable state:
  a guard of an earlier subscription may be dropped while the next registration is being made.
- Cancellation is the drop of the future, at any `.await`: there is no exception to rethrow, and what must run on
  cancellation is a guard (`async.rs.md`, Tasks).

### Threads

- In application code `std::thread::spawn` and `std::thread::Builder::spawn` start only blocking work that runs
  until shutdown, in a technology module, and the owner joins the thread when it stops. Kotlin uses no `Thread`;
  Rust keeps this one form because tokio sends such work to an ordinary thread: `spawn_blocking` "is intended for
  non-async operations that eventually finish on their own", its task cannot be aborted, and for work that runs
  indefinitely tokio says to "prefer a dedicated thread created with `thread::spawn`" (tokio 1.54,
  `spawn_blocking`). `clippy.toml` lists the paths `std::thread::spawn` and `std::thread::Builder::spawn` under
  `disallowed-methods`, so the function that starts the thread carries
  `#[expect(clippy::disallowed_methods, reason = "<the work that runs until shutdown>")]`.
- Blocking work that ends (a file read, a blocking client call, a heavy computation) runs in
  `tokio::task::spawn_blocking` and is awaited. Many CPU-bound computations go to `rayon` when the project already
  depends on it: tokio's documentation of `spawn_blocking` names "specialized CPU-bound executors, such as rayon"
  for them, since the blocking pool's thread limit is very large by default.
- An `async fn` never blocks its worker thread: `tokio::time::sleep`, not `std::thread::sleep`; `tokio::fs` or
  `spawn_blocking`, not `std::fs`; `tokio::sync` channels, not `std::sync::mpsc`. Between two `.await`s it runs
  for no more than 10 to 100 microseconds, the rule of thumb of Alice Ryhl, a tokio maintainer, in "Async: What is
  blocking?" (2020).
- Shared state and locks follow `async.rs.md`, Shared state and locks: `parking_lot` for a guard no `.await`
  crosses, `tokio::sync::Mutex` only across an `.await`, no `std` lock.
- A contract returns no `JoinHandle` and no `oneshot::Receiver`: a result that arrives later is an `async fn`. A
  timer is `tokio::time::interval` in a task of a `TaskScope`.
- A runtime is built and blocked on only in `main` of the entry-point crate, with `tokio::runtime::Builder` and
  never `#[tokio::main]` (`di-manual.rs.md`), and inside a technology module, where a library calls a synchronous
  callback on a thread of its own and that code must wait for async work, and in the `on_disable` of the DI module
  of a technology module, which runs after `main`'s `block_on` and waits for the shutdown of its own resource
  (`self.handle.block_on(self.<resource>.<shutdown>())`, `di-manual.rs.md`). `Handle::block_on` panics on a runtime
  thread. A test runs async code under `#[tokio::test]` (`testing.rs.md`).
