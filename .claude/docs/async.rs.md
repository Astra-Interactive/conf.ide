## Rust: async and tasks

These rules apply to code that runs on tokio, the project's async runtime. The `tokio::sync` channels are
runtime agnostic (tokio documents them so), so a contract or a state holder may name `watch::Receiver` the way
a Kotlin contract names `StateFlow`.

- A `watch` channel always holds a value. Read it with `borrow()`, copy or clone what the code needs, and let the
  `Ref` go before the next `.await`: a borrow holds the channel's read lock, and held across an `.await` it can
  deadlock the sender. A `timeout` wraps a call that can actually wait: a network call, `recv()`, `changed()`,
  `wait_for(predicate)` on a value that may not match yet. It never wraps a read that returns at once,
  `wait_for(|_| true)` or an `async` block with no `.await` in it: the timeout never fires and only hides what
  the code does.

  ```rust
  // Bad
  let content = timeout(Duration::from_secs(1), receiver.wait_for(|_| true)).await;

  // Good
  let content = receiver.borrow().clone();
  ```

- Writing a `watch::Sender`: `send_modify` or `send_if_modified` when the new value depends on the current one;
  `send_replace` when it does not. `send` is never called on a state holder: it fails when no receiver is
  subscribed, and then it stores nothing, so the next subscriber reads the old state.

  ```rust
  state.send_modify(|current| {
      *current = CheckoutState {
          is_busy: false,
          ..current.clone()
      }
  }); // depends on it
  state.send_replace(CheckoutState {
      order_id,
      stage: CheckoutStage::Finished,
      is_busy: false,
  }); // does not
  state.send(CheckoutState { order_id, stage: CheckoutStage::Finished, is_busy: false }) // never
  ```

- The closure of `send_modify` and `send_if_modified` runs exactly once, under the channel's write lock. It
  computes the new value from the current one and does nothing else: no I/O, no lock, no other channel. Because
  it cannot run twice, a captured `Option` may carry the stored value out; this is where Rust differs from
  Kotlin's `update`, whose lambda may run twice. The closure of an atomic's `fetch_update` is a compare-and-set
  loop that may run several times (std), so it is pure and writes nothing it captures: what was stored is the
  same transition applied to the previous value it returns. The transition itself is a rule of the model,
  placed by the domain rule.

  ```rust
  // checkout/util/checkout_state_ext.rs: the pure transition
  impl CheckoutState {
      pub(crate) fn start_payment(&self) -> Option<CheckoutState> {
          let is_payment_stage = self.stage == CheckoutStage::Payment;
          if !is_payment_stage || self.is_busy {
              return None;
          }
          Some(CheckoutState {
              is_busy: true,
              ..self.clone()
          })
      }
  }

  // the state holder
  fn claim_payment(&self) -> Option<CheckoutState> {
      let mut started = None;
      self.state.send_if_modified(|current| {
          let Some(next) = current.start_payment() else {
              return false;
          };
          *current = next.clone();
          started = Some(next);
          true
      });
      started
  }
  ```

- A task started by a request or a user action is guarded atomically against a second start. A flag in the
  state such as `is_busy` is what a reader shows, not a lock: two fast requests both read `false`. In order:
  1. the project's single-task holder when it has one, with the mode passed at every start, never left to a
     default: skip while running for a purchase, abort the previous for a search;
  2. otherwise a compare-and-set on the state through `send_if_modified` with a pure transition, as above: the
     guard and the `is_busy` display are one write;
  3. as the fallback `tokio::sync::Mutex::lock().await`, which queues the second request instead of skipping it,
     so the block re-checks the state before acting.

  ```rust
  // Bad: a second request starts a second purchase
  pub(crate) fn on_purchase(&self) {
      let purchase_order_use_case = Arc::clone(&self.purchase_order_use_case);
      let order_id = self.state.borrow().order_id;
      self.task_scope.spawn(async move {
          purchase_order_use_case.invoke(order_id).await;
      });
  }

  // Good
  pub(crate) fn on_purchase(&self) {
      let Some(started) = self.claim_payment() else {
          return;
      };
      let purchase_order_use_case = Arc::clone(&self.purchase_order_use_case);
      self.task_scope.spawn(async move {
          purchase_order_use_case.invoke(started.order_id).await;
      });
  }
  ```

- A result that arrives later is an `async fn`, things that happen are a stream or a channel receiver, and a
  library's callback is bridged once at its boundary: `no-callbacks.rs.md`.

### Tasks

- Every task has an owner that stops it and sees how it ended: a `TaskScope`, Kotlin's `CoroutineScope` with a
  `SupervisorJob` and a `CoroutineExceptionHandler`. A draining task owns the scope's `JoinSet`. `spawn` sends each
  new task to it over an unbounded `mpsc` channel, and the drain `select!`s between new tasks and `join_next()`, so
  every `JoinError` is read when its task ends, a panic is logged then, and no finished task is kept. `abort`
  aborts the drain: its `JoinSet` is dropped and aborts every task in it, and a task spawned after that is dropped
  unrun. A `JoinSet` behind a lock instead keeps every finished task until someone calls `join_next`, and the
  synchronous `on_disable` of `Lifecycle` cannot call it, since `join_next` is `async`.
- `tokio::spawn` whose `JoinHandle` is dropped (a bare statement, `let _ =`, `drop(…)`) detaches the task: nothing
  stops it, and its panic reaches no one. It is Kotlin's `GlobalScope.launch`, and it is not written; the drain's
  own `JoinHandle` is kept by its scope.

  ```rust
  // Bad
  tokio::spawn(async move { reminder.run().await });

  // Good
  self.task_scope.spawn(async move { reminder.run().await });
  ```

- The scope is a small type written once, in `core` when two or more units use it at creation, else in the unit
  that needs it, as `core` holds Kotlin's shared coroutine scopes (`arch-package.md`, Units 1); a later consumer
  uses it as `arch-package.md`, Existing code says. A DI module whose types start tasks either builds a scope of
  its own for them or hands them the shared scope that `CoreModule` holds; each such type receives an
  `Arc<TaskScope>`. The DI module that owns a scope calls its `spawn` in its `on_enable`, its `abort` in its
  `on_disable` and its `reload` in its `on_reload`, which hands the reloaded configuration to the scope's running
  tasks; a lifecycle method does nothing else for those tasks. A scope whose tasks read a configuration declares
  `reload`, which hands the reloaded configuration to each of its running tasks: in a tokio runtime through a
  `watch` channel the tasks observe (Shared state and locks, item 1), where the tasks are synchronous by calling
  each one's `reload`. The sketch below has no `reload`, its tasks read none. `new` spawns the drain, so it runs
  inside the runtime: `main` constructs `RootModule` inside `block_on` (`di-manual.rs.md`).

  ```rust
  // reminder/service/task_scope.rs, beside its only user, reminder/service/invoice_reminder.rs
  type Task = Pin<Box<dyn Future<Output = ()> + Send>>;

  pub(crate) struct TaskScope {
      tasks: mpsc::UnboundedSender<Task>,
      drain: JoinHandle<()>,
  }

  impl TaskScope {
      pub(crate) fn new() -> Self {
          let (tasks, receiver) = mpsc::unbounded_channel();
          let drain = tokio::spawn(Self::drain(receiver));
          Self { tasks, drain }
      }

      async fn drain(mut receiver: mpsc::UnboundedReceiver<Task>) {
          let mut running = JoinSet::new();
          loop {
              tokio::select! {
                  task = receiver.recv() => {
                      let Some(task) = task else {
                          return;
                      };
                      running.spawn(task);
                  }
                  Some(joined) = running.join_next() => {
                      let Err(error) = joined else {
                          continue;
                      };
                      if error.is_panic() {
                          tracing::error!(error = &error as &dyn Error, "A task panicked");
                      }
                  }
              }
          }
      }

      pub(crate) fn spawn(&self, task: impl Future<Output = ()> + Send + 'static) {
          #[expect(
              clippy::let_underscore_must_use,
              reason = "the drain is gone only after abort, and a task spawned then is refused on purpose"
          )]
          let _ = self.tasks.send(Box::pin(task));
      }

      pub(crate) fn abort(&self) {
          self.drain.abort();
      }
  }
  ```

- A `JoinHandle` that code awaits itself (the one of `spawn_blocking`, one in a test) gives a
  `Result<T, JoinError>`, which is consumed like any `Result` (`error-handling.rs.md`), never dropped.
- A future is cancelled by being dropped, at any `.await`; there is no exception to rethrow. Cleanup that must
  run on cancellation is a `Drop` guard (`no-callbacks.rs.md`, Cleanup). In a `tokio::select!` that runs in a
  loop, every branch is cancel safe (`mpsc::Receiver::recv`, `broadcast::Receiver::recv`,
  `watch::Receiver::changed`, `JoinSet::join_next`), or its future is created once before the loop and polled
  through `&mut`:
  `read_exact`, `read_to_end`, `write_all` and `tokio::sync::Mutex::lock` lose data or their place in the queue
  when another branch wins (tokio, `select!`, Cancellation safety).

### Shared state and locks

Kotlin keeps shared state in a `MutableStateFlow` written with `update` and uses a lock only as the fallback. A
Kotlin lock (`Mutex.withLock`, `synchronized`) releases when its block throws and keeps what the block wrote. Rust
keeps that order and those semantics. Only `std`'s locks differ: they poison.

1. State a reader observes is a `watch` channel written with `send_modify` or `send_if_modified` (above). A counter
   or a flag is an atomic. A resource that one task can own (a connection, a file) is owned by that task and reached
   through an `mpsc` channel. A lock is only for data none of these fit, such as a map several tasks read and write.
2. A lock whose guard no `.await` crosses is `parking_lot::Mutex` or `parking_lot::RwLock`, in synchronous and
   asynchronous code alike: tokio's own documentation prefers a blocking mutex for data (`tokio::sync::Mutex`,
   "Which kind of mutex should you use?").
   - `tokio::sync::Mutex` is only for a guard that must live across an `.await`.
   - A synchronous function on a runtime thread (a `Drop`, a synchronous `on_enable` or `on_reload`) cannot lock it:
     `blocking_lock` panics there.
   - `clippy::await_holding_lock` reports a `parking_lot` guard held across an `.await`.
3. `std::sync::Mutex` and `std::sync::RwLock` are not used, in tests and fakes either. After a panic inside the
   critical section `std` poisons the lock, and every later `lock()` returns `Err`. Kotlin's lock has no such state.
   - `std::sync::nonpoison` is unstable: E0658 on 1.93 and 1.99, issue #134645. Once it is stable on the
     project's toolchain, it replaces `parking_lot`.
   - `clippy.toml` lists `std::sync::Mutex`, `std::sync::RwLock` and `std::sync::PoisonError` under
     `disallowed-types`, with this rule as the reason.
   - `PoisonError` is never written outside the second exception below.
   - Two reviewed exceptions: a library API that demands a `std` lock; a crate that may take no dependency (a
     minimal published library), which uses the `std` lock with `unwrap_or_else(PoisonError::into_inner)` under
     rule 4. Both carry `#[expect(clippy::disallowed_types, reason = "…")]` on every item that names the lock or
     `PoisonError`, its `use` declaration included: clippy reports the `use`, the field type, the constructor call
     and `PoisonError::into_inner` each where it is written.
4. A critical section computes first and writes once. It reads what it needs and builds the new value with a pure
   rule (`util`, as Kotlin's `update` lambda). Then it stores the value in one statement, the last one in the
   guard's scope: `*cache = next;`, or one `insert` or `remove` on the guarded collection. A panic before that
   statement leaves the old state, and no statement follows it. Two related values that must change together are
   one value (one struct, or the entry of one map). A scope may end with the value it returns, when that
   expression only names a value: a literal, a path (a local, a parameter, a constant, `None`, a unit variant)
   or a field of such a value, also under unary minus or in parentheses (`let taken = compute(&cache);`, then
   `taken` or `taken.evicted`), also after `return`. That is the scope's result, not a statement after the write. A call,
   a method call, a macro, a block, an index or any other expression there is a statement.
5. Nothing here hides the panic. It ends its task, and the task's scope logs it from the `JoinError` (Tasks).

```rust
// Bad: std lock, poison ignored, two writes
let mut cache = self.cache.lock().unwrap_or_else(PoisonError::into_inner);
cache.invoices.insert(invoice.id, invoice);
cache.refreshed_at = now;

// Good: invoice/memory/in_memory_invoice_cache.rs, cache: parking_lot::Mutex<HashMap<InvoiceId, CachedInvoice>>
let mut cache = self.cache.lock();
cache.insert(
    invoice.id,
    CachedInvoice {
        invoice,
        refreshed_at: now,
    },
);
```
