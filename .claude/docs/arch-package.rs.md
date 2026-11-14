## Rust: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Cargo and the Rust module system
express it: a unit is a crate, a package is a module whose path is its directory, and a Kotlin source set is code
under a target `#[cfg]`. Where Rust needs a form of its own, the reason stands next to it.

### Modules and directories

- The directory is the module. The crate's root file, `src/lib.rs` (`src/main.rs` in a tooling crate), declares the
  whole module tree as nested inline blocks, one block per concept and per kind, and each kind block declares its
  files with `mod <file>;`. The compiler loads `mod issue_invoice_use_case;` inside `invoice { usecase { … } }` from
  `src/invoice/usecase/issue_invoice_use_case.rs`, so the directory tree is the module tree, as in Kotlin.

  ```rust
  // modules/billing/api/src/lib.rs
  pub mod invoice {
      pub mod api {
          pub use invoice_repository::InvoiceRepository;
          mod invoice_repository;
      }
      pub mod model {
          pub use invoice::Invoice;
          pub use invoice_error::InvoiceError;
          mod invoice;
          mod invoice_error;
      }
      pub mod usecase {
          pub use issue_invoice_use_case::IssueInvoiceUseCase;
          mod issue_invoice_use_case;
      }
      pub(crate) mod util {
          mod invoice_ext;
      }
      pub(crate) mod file {
          pub(crate) use file_invoice_repository::FileInvoiceRepository;
          mod file_invoice_repository;
      }
      pub mod di {
          pub use invoice_module::InvoiceModule;
          mod invoice_module;
      }
  }

  #[cfg(test)]
  #[path = "../test"]
  mod test {
      mod invoice {
          pub(crate) mod fake {
              pub(crate) use fake_invoice_repository::FakeInvoiceRepository;
              mod fake_invoice_repository;
          }
          mod usecase {
              mod issue_invoice_use_case_test;
          }
      }
  }
  ```

- Only the root file declares modules: there is no `mod.rs`, no `invoice.rs` beside an `invoice/` directory,
  and no `mod` inside a file module. Clippy's `mod_module_files` and `self_named_module_files` are both on in
  `[workspace.lints.clippy]`: together they report every file module that loads a file of its own, and the
  layout above passes both.
- The root file holds the module tree and nothing else, except inner attributes and `//!` lines at its top, the
  items the platform calls in an entry-point crate (Entry points) with the `use` declarations those items need,
  the `#[proc_macro]`, `#[proc_macro_derive]` and `#[proc_macro_attribute]` `pub fn`s of a `proc-macro` crate with
  the `use` declarations they need (rustc requires them at the crate root: Reference, Procedural macros), and, as
  its last items, the fixture block and the test block (Tests). Inside a block the `use` lines come
  first, then the `mod` lines: the Rust Style Guide puts imports before module declarations (Items), and
  `code-ordering.rs.md` rule 1 puts `use` first in every scope.
- A file module is private (`mod invoice;`, no visibility). Its kind block re-exports each of its items once, by
  name: `pub use` for what another crate uses, `pub(crate) use` for the rest of the crate. The path to a type is
  its package path (`crate::invoice::model::Invoice`, `shop_billing_api::invoice::model::Invoice` from another
  crate); the file name appears in no path. A type has exactly that one path: no glob re-export
  (`pub use x::*`), no `prelude` module, no re-export at the crate root.
- A concept or kind block is `pub` when it or a block inside it re-exports something with `pub use`, and
  `pub(crate)` otherwise. The test block and every block inside it are private, except a kind block there that
  re-exports something with `pub(crate) use` (the `fake` block above): it is `pub(crate)`, so that the tests of
  every concept reach what it re-exports. Rust modules could hide one concept from the rest of the crate; this
  layout does not use that: the `test/` tree, a sibling of every source module, sees only what is `pub(crate)`
  (E0603 on a narrower item), and `arch-context.md` holds the direction between concepts.
- `#[path]` appears on the fixture block and the test block and nowhere else.
- Platform code (Kotlin's `androidMain`, `iosMain`) is code under a target `cfg` (`target_os`, `target_family`,
  `unix`, `windows`, `target_arch`) at the same module path, never in a module named after the platform. The kind
  block declares one file per platform under its `cfg` and re-exports the same name from each; the file carries
  the `cfg` value as a suffix, as a Kotlin `actual` file carries its source set:

  ```rust
  pub(crate) mod api {
      #[cfg(target_os = "linux")]
      pub(crate) use clipboard_linux::Clipboard;
      #[cfg(target_os = "macos")]
      pub(crate) use clipboard_macos::Clipboard;
      #[cfg(target_os = "linux")]
      mod clipboard_linux;
      #[cfg(target_os = "macos")]
      mod clipboard_macos;
  }
  ```

  A platform's dependency sits in `[target.'cfg(…)'.dependencies]`. The shared code is a library crate; each
  platform's application is an entry-point crate of its own; there is no `shared` crate.
- Module names follow the package naming of `arch-package.md` (Concepts and kinds 9-10) in Rust's case:
  snake_case, singular, one module per concept (`order_line` when the project's word has two words). Never a
  module name, besides that list: `prelude`; `test` and `fixture`, which the test and fixture blocks take; `bin`
  directly under `src/`, because Cargo builds every `src/bin/*.rs` as a binary; `std`, `core` and `alloc`, which
  hide the standard crates from the `use` lines of the parent block (E0432); a Rust keyword. `api` is both a
  crate name (`shop-billing-api`) and a kind module; `impl` is only part of a crate name, in apps.
- A technology module is named after a crate the crate depends on, or `file`, `memory`, as in `arch-package.md`.
  The name is the dependency's full name with `-` as `_` (`aws_sdk_s3`) or its first word (`aws`), unless that
  first word is generic: `alloc`, `async`, `common`, `core`, `derive`, `lib`, `macros`, `rt`, `runtime`, `rust`,
  `std`, `sync`, `sys`, `util`, `utils` (`async-trait` gives only `async_trait`). As `file` and `memory` name
  implementations built on the standard library's files and memory, `system` names one built on its access to
  the operating system, such as the system clock (`time-api.rs.md`). Kotlin needs no such word, since its
  standard library ships `Clock.System`; the module is not named `std` (above).
- In a crate that is wholly one technology (`arch-package.md`, Concepts and kinds 2) an implementation is a type
  with an `impl` of a contract: a trait of an `api` module of the workspace, or a trait that the technology's or
  the host's library declares for the code it calls (`CommandHandler`). An `impl` of a standard trait (`Drop`,
  `Default`, `Display`, `From`) makes no implementation: a type that has only those sits directly in the concept
  when an implementation of that concept uses it, and otherwise in the kind that `arch-package.md`, Concepts and
  kinds 8 gives it: the role kind when no other kind fits (Concepts and kinds 3).
- `composable`, `theme` and `viewmodel` are Compose and Android words and are not used in Rust; a Rust UI crate
  takes its kind words from its UI framework and the project (`arch-package.md`, Concepts and kinds 4).

### Visibility

Rust items are private unless marked, and the module tree above does not encapsulate, so the visibility of an
item is its tier. Decide it while writing the declaration:

| Declaration | Visibility |
|---|---|
| used only inside the file that declares it | private (no modifier) |
| used by other files of the same crate, such as an implementation its DI module constructs | `pub(crate)` |
| used by another crate: the contracts, models, model rules and use cases of an `api` crate, the `stub` and `memory` implementations another crate uses, the shared fakes of the fixture tree, a DI module another crate constructs, the items `main.rs` uses, the items a host calls in a library it loads | `pub` |

- Fields and methods take the tier of their widest user the same way: private unless another file uses them,
  and never `pub` on a type that is not `pub`. `unreachable_pub` is on in `[workspace.lints.rust]` and reports a
  `pub` item or method that no other crate can reach, not a field.
- The items the platform calls in an entry-point crate take the visibility the platform demands: `fn main` of a
  binary has none, and the functions or the plugin type a host loads from a library are `pub`. Entry points
  (`InvoiceCommand`, `InvoiceListener`) are `pub(crate)`: other crates construct the crate's DI module, not its
  types. Two exceptions are `pub`: the public interface of an app `api` state holder (`arch-package.md`, Concepts
  and kinds), and a platform event type in the `event` kind (`arch-domain.rs.md`), which is declared for other
  programs, reached through the host, and carries the host's event derive or trait.
  The test tree is part of the crate and sees `pub(crate)`, so nothing in production is widened for
  same-crate tests. A fake of the fixture tree is `pub` for its test consumers; a fake of the test tree is
  `pub(crate)`.
- Kotlin's explicit API mode has no Rust counterpart: every `pub` is already written on purpose, and
  `unreachable_pub` reports one that no other crate can reach, in a published crate and an application crate
  alike.
- An item one library crate needs from another, but no consumer of the library should use, is `pub` and marked
  `#[doc(hidden)]` in the module where it is, as Kotlin marks it with a `@RequiresOptIn` annotation; it is never
  placed in a module named `internal`. Stable Rust has no opt-in for a crate's own items, and a Cargo feature
  does not hide the item: features are unified, so a consumer that depends on both crates gets the feature
  switched on too (Cargo Book, Features). Each `#[doc(hidden)] pub` item is used by another crate of the
  workspace. Moving the item into a new crate that both depend on is a cut the author decides
  (`arch-package.md`, Units 2), not part of this rule.
- Unsafe code sits in the technology module of the library or system interface it calls, behind a safe
  implementation of a contract. Kotlin has no `unsafe`; the kind rules place it, since what `unsafe` calls (a C
  library, a system call) is the technology that module wraps, and every other module then stays safe code.

```rust
// modules/billing/api: invoice/file/file_invoice_repository.rs, used by InvoiceModule in the same crate
pub(crate) struct FileInvoiceRepository {
    folder: PathBuf,
}
```

### Units and Cargo

- The root `Cargo.toml` is a virtual manifest: `[workspace]` and no `[package]`, and the root holds no `src/`. A
  project of one crate is a workspace of one member. The root `[workspace]` sets `resolver = "3"`: a virtual
  manifest otherwise gets resolver 1, which builds a dev-dependency's features into normal builds, so the `fake`
  feature of Tests would reach `cargo build --release`; and 3, not 2, because only Rust-version-aware resolution
  keeps a dependency's dependencies within the project's toolchain.
- `members` lists each crate's path (`"modules/billing/api"`), as `settings.gradle.kts` includes each unit. A
  glob is not used: `modules/*` also matches the container `modules/billing`, and Cargo stops with
  `failed to load manifest for workspace member`.
- Product crates sit under `modules/` (`arch-package.md`, Units 3), entry-point crates under `instances/<name>`,
  and `xtask/` at the root. A container directory (`arch-package.md`, Units 7) holds crate directories and nothing else, an optional
  `README.md` aside.
- A crate's `name` is the project prefix followed by its path without the container, `/` replaced by `-`:
  `modules/billing/api` → `shop-billing-api`, `modules/event-host` → `shop-event-host`, `instances/cli` →
  `shop-cli`. A project keeps the convention it has, and a new crate takes the name its neighbours would give
  it. `[lib] name` is never set, so the import path is the name with `_` (`shop_billing_api`). The prefix also
  keeps a crate from hiding a standard crate: a dependency named `core` makes `core::fmt` unresolvable (E0433).
- A library crate is `src/lib.rs`. A binary entry-point crate is `src/lib.rs`, which declares the module tree and the
  test block, plus `src/main.rs`, which holds `use` lines and `fn main` and declares no module. A tooling crate
  (`xtask`) is `src/main.rs` alone. `src/bin/` is not used: several binaries are several entry-point crates.
- The project declares its product kind once, `[workspace.metadata.klibs-rules] product-kind = "platform-plugin"`
  when it is built once per host framework (a plugin loaded by several hosts), `"app"` otherwise; every crate
  inherits it. Beside it, `platform-words` lists the project's host frameworks (`platform-words = ["bukkit",
  "velocity"]`), the words of its platform crates: Rust has no fixed set of hosts, and a Gradle unit needs no such
  list, since its convention plugin names its type.
- A crate declares its role in `[package.metadata.klibs-rules] role`, the counterpart of the convention plugin of
  a Gradle unit, for every crate the linter's detection does not cover (always `core` and `impl-ui`); the words
  of the project's host frameworks go into `platform-words`, so that its platform crates are covered:

  | Role | The crate |
  |---|---|
  | `tooling` | build automation, no product code |
  | `proc-macro` | the procedural macros of a sub-context |
  | `entry-point` | the items the platform calls and `RootModule` |
  | `core-ui` | the design system |
  | `core-platform` | shared platform code |
  | `core-api` | shared platform-free code |
  | `core` | an unsplit core of an app, with no project dependencies |
  | `contract` | wire types a server and its client share |
  | `storage-contract` | storage contracts (`data/dao`) |
  | `api` | platform-free code other crates call |
  | `impl` | an app's implementation of a feature |
  | `impl-ui` | an app's UI of a feature |
  | `platform` | a feature's platform implementation |
  | `technology` | one technology's implementation (`data/sqlx`) |
  | `context` | an unsplit sub-context |

  A crate whose only library target is a `cdylib` or a `staticlib` is an entry point: no crate can use it (Cargo
  warns that it "provides no linkable target", a `use` of it fails with E0432 and a path into it with E0433), so
  only a host loads it.

  `tooling` and `proc-macro` are Rust's own: Cargo has no included build, so `xtask` is a workspace member, and a
  procedural macro is a `pub fn` at the root of a crate of its own (Reference, Procedural macros). A
  `proc-macro` crate depends on no crate of the project, and any production crate may depend on it, since the
  crates that expand its macros need it in their normal build. There is no fake role: shared fakes are a feature
  of the crate they fake (Tests).
- Shared settings are declared once in the root: `[workspace.package]`, `[workspace.dependencies]` and
  `[workspace.lints]`, which a member takes with `….workspace = true` and `[lints] workspace = true`, the way a
  unit applies a convention plugin. Every member takes the lints. `[profile.*]`, `[patch]` and `[replace]` stay
  in the root manifest: Cargo ignores them in a member.
- A dependency is declared by the crate that uses it. A crate never re-exports another crate's item
  (`pub use other_crate::…`); a consumer declares its own dependency. A type in a crate's public signatures
  still reaches its consumers as a value (a consumer of `pub struct InvoiceId(pub Uuid)` holds a `Uuid`), and
  Cargo's `public` flag, which would track that, is ignored on stable.
- A plugin's `api` crate (`modules/billing/api`) names no platform crate in its manifest; the platform crate
  (`modules/billing/<host>`, named after the host framework) depends on it (`arch-package.md`, Units 4). An
  app's `api` crate names a platform crate only under `[target.'cfg(…)'.dependencies]`.
- Dependencies between crates follow the second table of `arch-context.md`. Cargo rejects a cycle of normal
  dependencies, but only warns about a dependency on a crate with no library ("ignoring invalid dependency")
  and accepts a cycle through `[dev-dependencies]`; the tables allow neither.
- The types of a `contract` crate derive `serde`'s `Serialize` and `Deserialize` (`arch-package.md`, Units 1).
- A published crate declares `version`. Every other crate omits it: Cargo then treats the crate as `0.0.0` and
  refuses to publish it (`publish` is `[]` in `cargo metadata`), which is how Kotlin's unpublished unit lacks
  `maven-publish`.
- Build automation (code generation, release steps, the architecture check) is a subcommand of the `xtask`
  crate, run as `cargo xtask <task>` through `[alias] xtask = "run --package xtask --"` in
  `.cargo/config.toml`, never a shell script. It holds no product code, depends on no crate of the project, and
  nothing depends on it, as Kotlin's `build-logic` is an included build that no unit depends on and that depends on
  no unit.
- The `README.md` of a crate (`arch-package.md`, Units 8) is the package readme Cargo takes.

### Entry points, use cases and the platform

- `event` holds listeners named `<Subject>Listener` and the platform's own event types named `<Name>Event`
  (`arch-package.md`, Concepts and kinds 8; `arch-domain.rs.md`), a plain-data type (one with no hand-written
  `impl` that holds a function) in a file that declares a listener or an event type, and no free function or
  `static`. A guard whose `Drop` is the teardown of a job sits beside the job: Rust runs teardown through `Drop`
  where Kotlin has `onDisable`. A class a listener uses is not an entry point: it is placed by
  `arch-package.md`, Concepts and kinds 8, and state kept between calls goes behind a contract (the fifth trigger
  of `arch-package.md`, Contracts and implementations).
- In an entry-point crate (`arch-package.md`, Units 1) the platform calls `fn main` of `src/main.rs` in a binary,
  which builds the async runtime, constructs `RootModule` from the library (`shop_cli::di::RootModule`) and
  drives its lifecycle (`di-manual.rs.md`); in a library a host loads (`crate-type = ["cdylib"]`), the functions
  or the plugin type the host calls are in `src/lib.rs`.
- A framework registration interface is a trait in the module of its mechanism (`route`, `command`), under the
  signature restrictions of `arch-package.md`.
- A state holder (the type that keeps the `watch::Sender` a UI or another reader observes, `async.rs.md`) holds no
  rule and calls use cases and contracts.

### DI modules

Which crate has a DI module (`crate::invoice::di::InvoiceModule`, `crate::di::BillingModule`), who owns each
lifecycle and what `RootModule` lists: `di-manual.rs.md`.

### What goes in one file

- A file module holds one type family and is named after it in snake_case (`file_invoice_repository.rs` holds
  `FileInvoiceRepository`): an enum with its variants and the payload structs only its variants carry, or a
  struct with the plain-data structs and enums only its fields use. Rust cannot nest a type in a type, so
  nested means declared in the same file, after the type that uses it.
- A type has behaviour (`arch-package.md`, Files) when it has a hand-written `impl` block with a function body, a
  trait `impl` included; a derive is not behaviour.
- The type's file holds its derives, its `impl` blocks and its trait `impl`s; what a model's file may hold is in
  `arch-domain.rs.md`. A file that declares a type holds no free function: a helper is a private associated
  function of the `impl`, or a function in the `util` of the level that uses it. A `type` alias names a type
  and forms no type family: a file that holds aliases and free functions and declares no struct, enum, union or
  trait is a function file for this rule, and its functions stand there. Such a file is in practice a test file,
  whose aliases name the types its test functions share; a `util` file still holds no `type` alias, so a helper
  that needs a long type spells it or takes a model type.
- A type that is a field type of exactly one type sits in that type's file, as does an enum used only through
  one type; any other type is its own file.
- A contract of this crate implemented for a type another crate declares (`impl InvoiceScreen for Window`; the
  orphan rule allows it because the trait is local) is Rust's form of a Kotlin adapter class that would hold only
  that value. The `impl` stands alone in a file of the technology module named after the type's crate, named
  `<type>_<contract>.rs` (`toolkit/window_invoice_screen.rs`); in a crate that is wholly that technology, directly
  in the concept. The file declares no type. An adapter that needs a field of its own is a struct named by its
  technology, like every implementation. A contract implemented for a standard-library type
  (`impl Clock for SystemTime`) gets no file in a module named `std`, `core` or `alloc` (above): the implementation
  is a wrapper type in the technology module named after what it reads (`system`, `file`, `memory`), as
  `SystemClock` in `time-api.rs.md`. A blanket impl that only forwards a contract through a standard pointer
  (`impl<T: Contract + ?Sized> Contract for Arc<T>`, also `Box`, `Rc` and `&T`) is not an implementation for a
  standard-library type: it stays beside the contract.
- A `util` file holds functions. `<type>_ext.rs` holds the rules of one type: an `impl <Type>` block when the
  type is declared in this crate, or a trait `<Type>Ext` with its one `impl` when another crate declares the
  type (an inherent `impl` of another crate's type does not compile, E0116). A file of free functions is named
  after what they do (`duration_format.rs`, `transfer_limit.rs` for a rule over several types); never
  `utils.rs`, `helpers.rs` or `extensions.rs`. A `const` or `static` that the functions of a `util` file use, or
  that the `impl` of its `<Type>Ext` trait uses, may stay in that file; a file with no function and no `impl`
  holds no `const` or `static`.
- Never an item (`struct`, `enum`, `union`, `trait`, `impl`, `mod`) inside a function body. Functions are never
  grouped as associated functions of a type with no field and no trait `impl`.
- A file whose first line is a comment containing `@generated` is a tool's output (prost-build writes
  `// This file is @generated by prost-build.`): the rules of this section, `code-ordering.rs.md`,
  `imports.rs.md` and `region.md` do not apply to its contents. The `mod` line that declares it follows Modules
  and directories.

### Tests

- Each crate has a `test/` tree beside `src/` that mirrors it module for module:
  `src/invoice/usecase/issue_invoice_use_case.rs` is tested by
  `test/invoice/usecase/issue_invoice_use_case_test.rs`. A test file is named after the file of the owner of the
  behaviour it checks (a use case, a repository implementation, a model rule, an entry point), with `_test`; a
  type with no behaviour of its own gets no test file.
- The test tree is declared once, as the last item of the root file, by a block that mirrors the source blocks
  (Modules and directories). It is part of the crate, sees `pub(crate)`, and imports through the kind modules
  (`use crate::invoice::usecase::IssueInvoiceUseCase;`). Apart from that block and the fixture block, no
  `#[cfg(test)]` code sits in `src/`.
- A `Fake…` scripts failures or records calls. A file of a `fake` module declares a `Fake…` type, and a double
  under another name is not written: one that scripts or records is named `Fake…`, one that only stores is the
  `InMemory…` below. A same-crate fake lives in the test tree, in `fake/` inside the concept of the trait it
  replaces (`test/invoice/fake/fake_invoice_repository.rs`), `pub(crate)`, re-exported by the test tree's `fake`
  block. A double that only stores values in memory is not a fake but an in-memory implementation,
  `InMemory<Trait>` in the `memory` module of the concept: in `src/` when production code uses it or, from a
  plugin's `api` crate or the storage contracts crate only, another crate does (an app's other crates take a
  `stub` in `api` or the `fake` feature), and in the test tree (`test/invoice/memory/in_memory_invoice_repository.rs`)
  when only the crate's own tests construct it. Kotlin follows the same rule for its own unit. The reason for the
  test tree is Rust's: an item that only tests use is dead code in the crate's normal build, which `dead_code`
  under `-D warnings` stops, and the `#[cfg(test)]` that would exempt it is kept out of `src/` (above).
- A fake that tests of other crates need lives in the fixture tree of the crate that owns the trait, Kotlin's
  `testFixtures`: a `fixture/` directory beside `src/` and `test/` that mirrors `src/`
  (`fixture/invoice/fake/fake_invoice_repository.rs`), `pub`, and never copied into each consumer. The crate
  declares the feature `fake = []` in `[features]`, and its root file declares the fixture block just before the
  test block:

  ```rust
  #[cfg(any(test, feature = "fake"))]
  #[path = "../fixture"]
  pub mod fixture {
      pub mod invoice {
          pub mod fake {
              pub use fake_invoice_repository::FakeInvoiceRepository;
              mod fake_invoice_repository;
          }
      }
  }
  ```

  The crate's own tests use the fake as `crate::fixture::invoice::fake::FakeInvoiceRepository`, as a Kotlin
  unit's tests use its `testFixtures`. Another crate enables the feature only in `[dev-dependencies]`, never in
  `[dependencies]`, so it reaches the fake from its test tree alone:

  ```toml
  [dependencies]
  shop-billing-api = { path = "../api" }

  [dev-dependencies]
  shop-billing-api = { path = "../api", features = ["fake"] }
  ```

  Cargo builds the feature into every target of a command that builds tests (`cargo test --workspace`, `cargo
  build --all-targets`); a release artefact is built without them (`cargo build --release -p shop-cli`), and the
  fixture tree stays out of it. A separate fake crate is not used: the crate it fakes cannot take it, because its
  tests would compile against a second copy of the crate and the fake would implement the trait of the first copy
  (E0277, "there are multiple different versions of crate"), so that crate's tests would need a copy of the fake.
- Integration tests exist in two cases, each as one crate, `tests/it/main.rs`, whose nested blocks mirror `src/`:
  the public API of a published crate (one that declares `version`), reached through the crate's name, and the
  macro expansion of a `proc-macro` crate, since a procedural macro cannot be used in the crate that defines it.
  Every other test of a crate is in its `test/` tree, the tests of the wired application in the entry-point
  crate's.
- Three suites: in each sub-context's crate, model rules tested directly, use cases with fakes or in-memory
  implementations, technology modules against the real technology where it runs in a test (a database crate on
  a temporary database, a file store on a temporary directory); in the entry-point crate, tests of the wired
  application; architecture tests as their own suite.
- `benches/`, `examples/` and `build.rs` keep their Cargo meaning.
