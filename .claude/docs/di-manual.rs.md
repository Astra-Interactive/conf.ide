## Dependency Injection

Manual constructor injection: no DI framework crate and no service locator.

A DI module is a Rust `struct` (`InvoiceModule`) that holds its services as fields, constructs their concrete
instances in `new`, and receives other DI modules as parameters of `new`. Use a struct by default. Make a DI
module a trait with a separate implementation only on a trigger of the package-layout rule (Contracts and
implementations). "DI module" names this struct only; a Rust `mod` is a package and a crate is a unit.

A service is held as `Arc<dyn Contract>` when it has a contract and as `Arc<Type>` when it has none (a use case),
so the DI module and every consumer share one instance, as Kotlin shares one reference. A contract is never a
type parameter of a DI module, a use case or an entry point: Kotlin's interface-typed parameter is `Arc<dyn …>`.

`RootModule` is the composition root: the one DI module per application that builds the root DI modules in
dependency order. A field whose construction must be deferred is a `std::sync::OnceLock<T>` that an accessor fills
with `get_or_init`, Rust's form of Kotlin's `lazy {}`. A project that already names its composition root
otherwise keeps that name, and the rules about `RootModule` apply to it. It lives in `src/di/root_module.rs` of
the entry-point crate. `fn main`, the item the platform calls, builds the async runtime, creates `RootModule`,
calls its `on_enable`, keeps the process running until shutdown, then calls `on_disable` (the last example
below).

```rust
// modules/billing/api: invoice/di/invoice_module.rs, public because the entry-point crate constructs it
pub struct InvoiceModule {
    pub(crate) invoice_repository: Arc<dyn InvoiceRepository>,
    pub(crate) pay_invoice_use_case: Arc<PayInvoiceUseCase>,
}

impl InvoiceModule {
    pub fn new(core_module: &CoreModule) -> Self {
        let in_memory_invoice_repository = InMemoryInvoiceRepository::new();
        let invoice_repository: Arc<dyn InvoiceRepository> = Arc::new(in_memory_invoice_repository);
        let pay_invoice_use_case = Arc::new(PayInvoiceUseCase::new(
            Arc::clone(&invoice_repository),
            Arc::clone(&core_module.clock),
        ));
        Self {
            invoice_repository,
            pay_invoice_use_case,
        }
    }
}
```

- References between DI modules form an acyclic graph that follows the unit dependencies; several modules may
  receive the same DI module. A DI module receives another as `&OtherModule` in `new` and clones there the `Arc`s
  it keeps. Lifecycle ownership forms a tree: a module's children are only the DI modules it creates, which it
  owns as fields by value. Each unit that assembles dependencies has its own DI module in the `di` module of the
  level it wires (`invoice/di/invoice_module.rs`). A resource with its own lifecycle, such as a database pool, has
  its own DI module in the unit that owns it. Several DI modules in one unit are normal, and existing ones are
  never merged.
- Declaring a constructible type or allocating its own state is not dependency assembly. Tests may construct
  fakes directly; the fixture tree of shared fakes (`arch-package.rs.md`, Tests) needs no DI module. A type
  named `…Module` in the test or fixture tree is a fake of a DI-module trait, not wiring: the rule that a DI module
  sits in `di` reads `src/` only.
- A DI module that starts or stops something implements the project's `Lifecycle` trait (`on_enable`,
  `on_disable`, `on_reload`, all synchronous, as AstraLibs' `Lifecycle` is), and its methods call the same method
  of only the DI modules it owns, in order. It never starts, reloads or stops a DI module it received; it holds
  none. `RootModule` follows the same ownership rule. A DI module never replaces `Lifecycle` with its own
  `start()`, `reload()` or `stop()`, and never moves a child's work into its own `on_enable`. A lifecycle method
  holds no work of its own and calls no other method of its module: beside the forwards it calls only `spawn` of
  a scope the module owns or was handed, in `on_enable`, and `reload` and `abort` of the scope it owns (next item).
  The one exception is the `on_disable` of the DI module of a technology module (a DI module in a technology
  crate or technology module), which may block on the shutdown of an async resource it owns through the
  `tokio::runtime::Handle` it stored: `self.handle.block_on(self.<resource>.<shutdown>())`, one call and nothing
  else (`no-callbacks.rs.md`, Threads).
  What a Kotlin module writes inside `Lifecycle.Lambda` (`onReload = { configKrate.getValue() }`) is in Rust, in a
  crate with the job scope, the `start` or the `reload` of a `ScopedJob` on that scope; in a crate with an async
  runtime it is a task that observes a `watch` channel (`async.rs.md`, Tasks). A Rust call that can fail returns a
  `Result`, handling it is behaviour, and behaviour has a type and a test of its own. Whoever drives the lifecycle
  (`main`, a host's plugin type) calls its methods one at a time; a reload request that arrives elsewhere is
  handed to that driver. So a module, and what its lifecycle starts, guards nothing against two lifecycle calls at
  once. Kotlin takes `Lifecycle` from AstraLibs; Rust has no such library, so the project declares the trait in
  `core` when two or more units use it at creation, else in the `api` of the unit that needs it; a later consumer
  uses it where it is (`arch-package.md`, Units 1 and Existing code).
- A DI module whose types start tasks either owns a `TaskScope` for them or hands them the shared scope that
  `CoreModule` holds, as `core` holds Kotlin's shared coroutine scopes (`arch-package.md`, Units 1). A scope has
  one owner, the module that constructs it, which holds it by value, or as the `Arc<TaskScope>` it constructed
  itself when it hands clones out; only the owner calls its `abort` and `reload`. The owner constructs it
  directly in its constructor, as `TaskScope::new()` or `TaskScope::default()` (by value) or as
  `Arc::new(TaskScope::new())`, `Arc::new(TaskScope::default())` or `Arc::default()`, or through
  `#[derive(Default)]` on the owning type (a `TaskScope` or `Arc<TaskScope>` field); a local bound to one of these
  counts, and a scope reached through a helper function or another module is handed. A holder of a handed clone
  only spawns onto it (`async.rs.md`, Tasks). A DI module calls `spawn` in its `on_enable` onto a scope it owns or
  was handed; the one that owns the scope also calls its `abort` in its `on_disable` and its `reload` in its
  `on_reload`, which hands the reloaded configuration to the scope's running tasks. A lifecycle method does
  nothing else for those tasks, and `on_disable` waits for no task of a scope; the shutdown of a resource is not
  such a task (the exception above).

  ```rust
  // instances/server: di/root_module.rs, public because `main.rs` constructs it
  pub struct RootModule {
      core_module: CoreModule,
      invoice_module: InvoiceModule,
  }

  impl RootModule {
      pub fn new(config_path: PathBuf) -> Self {
          let core_module = CoreModule::new(config_path);
          let invoice_module = InvoiceModule::new(&core_module);
          Self {
              core_module,
              invoice_module,
          }
      }
  }

  impl Lifecycle for RootModule {
      fn on_enable(&self) {
          self.core_module.on_enable();
          self.invoice_module.on_enable();
      }

      fn on_disable(&self) {
          self.invoice_module.on_disable();
          self.core_module.on_disable();
      }
  }
  ```

- `RootModule` only builds the root DI modules and implements `Lifecycle` by calling theirs; it constructs no
  service itself. Configuration, a connection pool or a client is built by a DI module, the async runtime by
  `main`.
- `main` builds the runtime with `tokio::runtime::Builder`, never with `#[tokio::main]`. Inside `block_on` it
  constructs `RootModule` (a `TaskScope` spawns its drain in `new`), calls `on_enable` and waits for the shutdown
  signal; `block_on` returns `RootModule`, and `main` calls `on_disable` after it, while the runtime is still alive.
  This is Kotlin's shape: the platform calls `onDisable` on a thread that is not a coroutine. The DI module of a
  technology module may block there on the shutdown of its own async resource through the
  `tokio::runtime::Handle` it stored (`self.handle.block_on(self.<resource>.<shutdown>())`, above), which panics
  inside `#[tokio::main]` ("Cannot start a runtime from within a runtime") and works after `block_on` has
  returned. When `main` returns, the runtime is dropped with every task still in it.

  ```rust
  // instances/server: src/main.rs, after the `use` lines
  fn main() -> ExitCode {
      let runtime = match Builder::new_multi_thread().enable_all().build() {
          Ok(runtime) => runtime,
          Err(error) => {
              tracing::error!(
                  error = &error as &dyn Error,
                  "Could not start the async runtime"
              );
              return ExitCode::FAILURE;
          }
      };
      let root_module = runtime.block_on(async {
          let root_module = RootModule::new(PathBuf::from("config"));
          root_module.on_enable();
          if let Err(error) = tokio::signal::ctrl_c().await {
              tracing::error!(
                  error = &error as &dyn Error,
                  "Could not listen for the shutdown signal"
              );
          }
          root_module
      });
      root_module.on_disable();
      ExitCode::SUCCESS
  }
  ```
- A DI module is `pub(crate)` unless another crate constructs it.
- Pass the whole module as a dependency (`&CoreModule`), not individual services taken out of it. When the
  providing DI module sits in a unit the consumer may not depend on, the consumer's DI module takes the contract
  it needs as a parameter of `new` (`InvoiceModule::new(core_module: &CoreModule, invoice_cache: Arc<dyn
  InvoiceCache>)`).
- A task that seeds or migrates a resource (`warmup`, `migration`) is built by the DI module of that resource
  and started by its `on_enable`, through `spawn` of a scope the module owns or was handed.
- Never a service locator or a global singleton: no `static` holding a service or shared state (a `static` of
  `OnceLock`, `LazyLock`, `Mutex` or `RwLock`, `lazy_static!`). State shared between tasks is an `Arc<T>` passed
  down. A `static` holds only constant data. The one global is the logging subscriber, which `main` installs once:
  `tracing` and `log` dispatch through a global by design.
- These rules apply to the DI modules a task creates. Existing wiring that breaks them stays as it is until the
  user asks to change it.
