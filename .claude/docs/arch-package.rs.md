## Rust: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Cargo and the Rust module system
express it: a unit is a crate, a package is a module whose path is its directory, and a Kotlin source set is code
under a target `#[cfg]`. Where Rust needs a form of its own, the reason stands next to it.

### Modules and directories

- The directory is the module. The crate's root file (`src/lib.rs`; `src/main.rs` in a binary entry-point
  crate) declares the whole module tree as nested inline blocks, one block per concept and per kind, and each
  kind block declares its files with `mod <file>;`. The compiler loads `mod issue_invoice_use_case;` inside
  `invoice { usecase { … } }` from `src/invoice/usecase/issue_invoice_use_case.rs`, so the directory tree is
  the module tree, as in Kotlin.

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
  layout above passes both. An inline `mod … { }` inside a file module is left to the checker.
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
  layout does not use that, so that, as in Kotlin, the module organises and only the file and the crate
  encapsulate.
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
  `std`, `sync`, `sys`, `util`, `utils` (`async-trait` gives only `async_trait`), as Kotlin's checker takes a
  library's first word, generic words aside. As `file` and `memory` name implementations built on the standard
  library's files and memory, `system` names one built on its access to the operating system, such as the system
  clock (`time-api.rs.md`). Kotlin needs no such word, since its standard library ships `Clock.System`; the module
  is not named `std` (above).
- `composable`, `theme` and `viewmodel` are Compose and Android words and are not used in Rust; a Rust UI crate
  takes its kind words from its UI framework and the project (`arch-package.md`, Concepts and kinds 4).

### Visibility

Rust items are private unless marked, and the module tree above does not encapsulate, so the visibility of an
item is its tier. Decide it while writing the declaration:

| Declaration | Visibility |
|---|---|
| used only inside the file that declares it | private (no modifier) |
| used by other files of the same crate, such as an implementation its DI module constructs | `pub(crate)` |
| used by another crate: the contracts, models, model rules and use cases of an `api` crate, the `stub` and `memory` implementations another crate uses, the shared fakes of the fixture tree, a DI module another crate constructs, the items a host calls in a library it loads | `pub` |

- Fields and methods take the tier of their widest user the same way: private unless another file uses them,
  and never `pub` on a type that is not `pub`. `unreachable_pub` is on in `[workspace.lints.rust]` and reports a
  `pub` item or method that no other crate can reach; it does not report fields, so the checker does.
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
  `#[doc(hidden)]` in the module where it is, as Kotlin marks it with a `@RequiresOptIn` annotation
  (`InternalAstraLibsApi`); it is never placed in a module named `internal`. Stable Rust has no opt-in for a
  crate's own items, and a Cargo feature does not hide the item: features are unified, so a consumer that depends
  on both crates gets the feature switched on too (Cargo Book, Features). Each `#[doc(hidden)] pub` item is used
  by another crate of the workspace; the checker reports one that is not. Moving the item into a new crate that
  both depend on is a cut the author decides (`arch-package.md`, Units 2), not part of this rule.
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
  manifest otherwise gets resolver 1, and only Rust-version-aware resolution keeps a dependency's dependencies
  within the project's toolchain.
- `members` lists each crate's path (`"modules/billing/api"`), as `settings.gradle.kts` includes each unit. A
  glob is not used: `modules/*` also matches the container `modules/billing`, and Cargo stops with
  `failed to load manifest for workspace member`.
- Product crates sit under `modules/` (`arch-package.md`, Units 3), entry-point crates under `instances/<name>`,
  and `xtask/` at the root. A container directory holds crate directories and nothing else, an optional
  `README.md` aside: no `Cargo.toml`, no `src/`, no other file. A crate's directory never holds another crate.
- A crate's `name` is the project prefix followed by its path without the container, `/` replaced by `-`:
  `modules/billing/api` → `shop-billing-api`, `modules/event-host` → `shop-event-host`, `instances/cli` →
  `shop-cli`. A project keeps the convention it has, and a new crate takes the name its neighbours would give
  it. `[lib] name` is never set, so the import path is the name with `_` (`shop_billing_api`). The prefix also
  keeps a crate from hiding a standard crate: a dependency named `core` makes `core::fmt` unresolvable (E0433).
- A crate is a library (`src/lib.rs`) or one binary (`src/main.rs`), never both, and `src/bin/` is not used.
  Several binaries are several entry-point crates.
- The project declares its product kind once, `[workspace.metadata.klibs-rules] product-kind = "platform-plugin"`
  when it is built once per host framework (a plugin loaded by several hosts), `"app"` otherwise; every crate
  inherits it. Beside it, `platform-words` lists the project's host frameworks (`platform-words = ["bukkit",
  "velocity"]`), the words of its platform crates: Rust has no fixed set of hosts, and a Gradle unit needs no such
  list, since its convention plugin names its type.
- A crate declares its role in `[package.metadata.klibs-rules] role`, the counterpart of the convention plugin of
  a Gradle unit. Without it, the role comes from the first matching row:

  | Role | The crate | Detected when not declared |
  |---|---|---|
  | `tooling` | build automation, no product code | named `xtask` |
  | `proc-macro` | the procedural macros of a sub-context | `[lib] proc-macro = true` |
  | `entry-point` | the items the platform calls and `RootModule` | under `instances/`, or no Rust library target (`lib`, `rlib`, `dylib`, `proc-macro`) |
  | `core-ui` | the design system | `modules/core/ui` and below |
  | `core-platform` | shared platform code | `modules/core/<word>`, the word listed in `platform-words` |
  | `core-api` | shared platform-free code | `modules/core` itself and the other crates under it |
  | `core` | an unsplit core of an app, with no project dependencies | never |
  | `contract` | wire types a server and its client share | path ends with `contract` |
  | `storage-contract` | storage contracts (`data/dao`) | path ends with `dao` |
  | `api` | platform-free code other crates call | path ends with `api` |
  | `impl` | an app's implementation of a feature | path ends with `impl` |
  | `impl-ui` | an app's UI of a feature | never |
  | `platform` | a feature's platform implementation | path ends with a word listed in `platform-words` |
  | `technology` | one technology's implementation (`data/sqlx`) | path ends with a technology module's name for a crate it depends on (Modules and directories) |
  | `context` | an unsplit sub-context | anything else |

  A crate whose only library target is a `cdylib` or a `staticlib` is an entry point: no crate can use it (Cargo
  warns that it "provides no linkable target", a `use` of it fails with E0432 and a path into it with E0433), so
  only a host loads it.

  `platform` comes before `technology`: a platform crate is named after the host framework it depends on, so its
  path matches that dependency too. While `platform-words` is empty, no crate is detected as `platform` or
  `core-platform`, and such a crate declares its role.

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
  (`pub use other_crate::…`); a consumer declares its own dependency. This is Gradle's `implementation`: Cargo's
  `public` flag, the counterpart of `api`, is ignored on stable.
- In a plugin, an `api` crate (`modules/billing/api`) holds the platform-free code of its sub-context that other
  crates call: models, use cases, contracts and their platform-free implementations, with its own DI module.
  Its manifest names no platform crate. The platform crate (`modules/billing/<host>`, named after the host
  framework) depends on it and holds what uses the platform.
- In an app, an `api` crate holds contracts, the models in their signatures, the `util` rules of those models and
  stubs (`<concept>/stub/`), and names a platform crate only under `[target.'cfg(…)'.dependencies]`; the `impl`
  crate holds the rest. Only the entry-point crate depends on an `impl` crate, and a feature's UI crate (`impl-ui`)
  on the `impl` crate beside it.
- Dependencies between crates follow the second table of `arch-context.md`. Cargo rejects a cycle of normal
  dependencies, but only warns about a dependency on a crate with no library ("ignoring invalid dependency")
  and accepts a cycle through `[dev-dependencies]`; the checker reports both.
- A `contract` crate holds only types that derive `serde`'s `Serialize` and `Deserialize`, and route constants,
  shared by a server crate and its client crate; neither side's `model` crosses the wire.
- A published crate declares `version`. Every other crate omits it: Cargo then treats the crate as `0.0.0` and
  refuses to publish it (`publish` is `[]` in `cargo metadata`), which is how Kotlin's unpublished unit lacks
  `maven-publish`.
- Build automation (code generation, release steps, the architecture check) is a subcommand of the `xtask`
  crate, run as `cargo xtask <task>` through `[alias] xtask = "run --package xtask --"` in
  `.cargo/config.toml`, never a shell script. It holds no product code, depends on no crate of the project, and
  nothing depends on it, as Kotlin's `build-logic` is an included build that no unit depends on and that depends on
  no unit.
- Every crate has a one-sentence `README.md`; Cargo takes it as the package readme.
- These apply to new crates; existing paths and names stay.

### Entry points, use cases and the platform

- Entry points sit in kind modules named for the mechanism that invokes them, in the project's and the
  framework's words: `command`, `event`, `service` (run on a timer or its own lifecycle), `route`, `job`. A task
  run once at start is `warmup`, a format converter `migration`, a failure handler `error`. UI kinds come from
  the UI framework. Entry-point kinds and technology modules may use platform crates; `model`, `api` and
  `usecase` never do (`arch-domain.rs.md`).
- In `event` a type is a listener named `<Subject>Listener` or the platform's own event type named `<Name>Event`
  (`arch-package.md`, Concepts and kinds 8; `arch-domain.rs.md`). The checker reports any other struct, enum or
  union there, except a plain-data type (one with no hand-written `impl` that holds a function) in a file that
  declares a listener or an event type, and it reports a free function or a `static` there. A guard whose `Drop`
  is the teardown of a job sits beside the job: Rust runs teardown through `Drop` where Kotlin has `onDisable`.
  The checker reads the name only, so a helper renamed `…Listener` is the reviewer's to catch, and so is state
  handed to listeners as a bare `Arc<Mutex<…>>`: state kept between calls goes behind a contract
  (`arch-package.md`, Contracts and implementations, the fifth trigger).
- The root of the entry-point crate holds its `di` block, the `model` and `error` kinds of its framework failure
  type (`arch-domain.rs.md`, `error-handling.rs.md`) and the items the platform calls, nothing else. In a
  binary that is `fn main` in `src/main.rs`, which builds the async runtime, constructs `RootModule` and drives
  its lifecycle (`di-manual.rs.md`); in a library a host loads (`crate-type = ["cdylib"]`), the functions or the
  plugin type the host calls, in `src/lib.rs`.
- A use case is `<Verb><Object>UseCase` in the `usecase` module of its concept; its shape is in
  `arch-domain.rs.md`.
- A framework registration interface is a trait in the module of its mechanism (`route`, `command`), under the
  signature restrictions of `arch-package.md`.
- A state holder (the type that keeps the `watch::Sender` a UI or another reader observes, `async.rs.md`) holds no
  rule and calls use cases and contracts; it sits in the project's state-holder kind, and the design system is
  the `core-ui` crate.

### DI modules

Each crate that assembles dependencies has its own DI module in the `di` module of the level it wires
(`crate::invoice::di::InvoiceModule`, `crate::di::BillingModule`), and a resource with its own lifecycle has its
own DI module in the crate that owns it. A crate of contracts and models only has none; declaring fakes that
tests construct directly needs none either. `RootModule` sits in the `di` module of the entry-point crate. The DI
rule has the rest.

### What goes in one file

- A file module holds one type family and is named after it in snake_case (`file_invoice_repository.rs` holds
  `FileInvoiceRepository`): an enum with its variants and the payload structs only its variants carry, or a
  struct with the plain-data structs and enums only its fields use. Rust cannot nest a type in a type, so
  nested means declared in the same file, after the type that uses it.
- A type with behaviour always has its own file, even a private helper of one type. A type has behaviour when
  it has a hand-written `impl` block with a function body, a trait `impl` included; a derive is not behaviour.
- The type's file holds its derives, its `impl` blocks and its trait `impl`s; what a model's file may hold is in
  `arch-domain.rs.md`. A file that declares a type holds no free function: a helper is a private associated
  function of the `impl`, or a function in the `util` of the level that uses it, even when one file uses it.
- A type that is a field type of exactly one type sits in that type's file. A type returned to another type is
  its own file in `model`. An enum used only through one type sits in that type's file; otherwise it is its own
  file.
- A `util` file holds functions. `<type>_ext.rs` holds the rules of one type: an `impl <Type>` block when the
  type is declared in this crate, or a trait `<Type>Ext` with its one `impl` when another crate declares the
  type (an inherent `impl` of another crate's type does not compile, E0116). A file of free functions is named
  after what they do (`duration_format.rs`, `transfer_limit.rs` for a rule over several types); never
  `utils.rs`, `helpers.rs` or `extensions.rs`.
- Never an item (`struct`, `enum`, `union`, `trait`, `impl`, `mod`) inside a function body. Functions are never
  grouped as associated functions of a type with no field and no trait `impl`.
- A platform file carries its `cfg` suffix (`clipboard_linux.rs`).
- A file whose first line is a comment containing `@generated` is a tool's output (prost-build writes
  `// This file is @generated by prost-build.`): the rules of this section, `code-ordering.rs.md`,
  `imports.rs.md` and `region.md` do not apply to its contents, as Kotlin's checker skips the generated sources
  under `build/`. The `mod` line that declares it follows Modules and directories.

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
- A `Fake…` scripts failures or records calls. A same-crate fake lives in the test tree, in `fake/` inside the
  concept of the trait it replaces (`test/invoice/fake/fake_invoice_repository.rs`), `pub(crate)`, re-exported by
  the test tree's `fake` block. A double that only stores values in memory is not a fake but an in-memory
  implementation, `InMemory<Trait>` in the `memory` module of the concept: in `src/` when production code uses it or,
  from a plugin's `api` crate or the storage contracts crate only, another crate does (an app's other crates take a
  `stub` in `api` or the `fake` feature), and in the test tree (`test/invoice/memory/in_memory_invoice_repository.rs`) when only
  the crate's own tests construct it. Kotlin keeps it in production code either way; Rust cannot, because an item
  that only tests use is dead code in the crate's normal build, and `dead_code` under `-D warnings` stops it.
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
- There is no `tests/` directory: every test of a crate is in its `test/` tree, the tests of the wired
  application in the entry-point crate's. A `proc-macro` crate tests its helper code in its `test/` tree like any
  crate; only the tests that expand its macros sit in one integration-test crate, `tests/it/main.rs`, whose
  nested blocks mirror `src/` the same way, because a procedural macro cannot be used in the crate that defines
  it.
- Three suites: in each sub-context's crate, model rules tested directly, use cases with fakes or in-memory
  implementations, technology modules against the real technology where it runs in a test (a database crate on
  a temporary database, a file store on a temporary directory); in the entry-point crate, tests of the wired
  application; architecture tests as their own suite.
- `benches/`, `examples/` and `build.rs` keep their Cargo meaning.
