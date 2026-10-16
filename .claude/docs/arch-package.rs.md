## Rust: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Cargo and the Rust module system
express it. The tree is the same as in Kotlin; what differs is where the unit boundary falls, because a Rust
module encapsulates and a Kotlin package does not.

### Crates

- A project is one crate per build target. A context is a top-level module block of that crate, not a crate.
  A crate is split only for a need a module cannot meet: reuse by other projects, build time, a procedural
  macro, several binaries sharing code, control over a published API. When a workspace is split, its graph is
  wide, a vocabulary crate at the bottom and a leaf crate tying the rest together, components talk through
  `dyn` traits, and no generic code sits on a crate boundary.
- A workspace keeps its members flat under `crates/`, listed by `members = ["crates/*"]` in a virtual root
  manifest; crates published with semver go under `libs/`, so it is easy to check that they never depend on
  `crates/`; internal crates carry `version = "0.0.0"`. Profiles, patches and shared dependency versions are
  declared once in the root manifest. Build automation is an `xtask` crate, not shell scripts.
- A crate's directory is named exactly like the crate: kebab-case with the project prefix (`foo-core`,
  `foo-cli`), never sorted into folders. Modules are snake_case. A type never repeats its module's name
  (`io::Error`, not `io::IoError`), and a module is never named like its parent.
- Every crate carries a one-sentence `README.md`.

### The module tree

- Each crate has exactly one root file, `src/lib.rs` (a binary adds `src/main.rs` or `src/bin/<name>/main.rs`,
  which only parses arguments, wires and calls into the library). The root file holds the whole module tree as
  nested inline blocks and nothing else: no code, no logic.

  ```rust
  // src/lib.rs
  mod jail {
      pub(crate) mod model {
          mod jail;
          mod inmate;
          pub(crate) use inmate::{Inmate, InmateId};
          pub(crate) use jail::Jail;
      }
      mod data {
          mod repository;
          mod file;
          pub(crate) use repository::JailRepository;
          pub(crate) use file::FileJailRepository;
      }
      mod free_inmate;
      pub(crate) use free_inmate::FreeInmate;
  }
  ```

- The compiler resolves `mod jail;` inside the inline block `mod model` inside `mod jail` to
  `src/jail/model/jail.rs`, so every directory is a package exactly as in Kotlin. There is no `mod.rs`
  anywhere, and no `foo.rs` next to a `foo/` directory. Both Clippy module-file lints
  (`self_named_module_files`, `mod_module_files`) are off, because neither style applies.
- A file module is private. Its parent re-exports what the rest of the crate may see, by name, with
  `pub(crate) use` (or `pub use` at the crate root of a library), so the path to a type is the package path
  `jail::model::Jail` and the file name appears in no path. Glob re-exports (`pub use x::*`) and preludes are
  forbidden.
- A role of the package-layout rule is an inline block; a technology package beneath a contract is a nested
  block (`data { mod repository; mod file; … }`) and its implementation file is named by the technology.

### Visibility

- An item states its final reach: `pub(crate)` for everything the rest of the crate uses, bare `pub` only for
  an item a library exports, private for everything used by one file. `unreachable_pub` is switched on in
  every crate the task creates, so a `pub` item that is not exported is a warning.
- Plain data (a value object, a wire type) has public fields; a type with an invariant keeps its fields private
  and exposes methods.
- Unsafe code lives in the smallest module that can uphold its invariants, behind a safe wrapper that presents
  the interface.
- Between contexts in one crate the compiler enforces privacy but not direction: a module tree may form cycles.
  The acyclic, one-direction rule between context blocks is enforced by the checker in CI.

### Contracts and implementations

- A contract is a trait at its role level (`jail::data::JailRepository`); its implementation is a struct one
  level down, in the file named by its technology (`jail/data/file.rs` holding `FileJailRepository`). The
  trait takes the plain name; the struct carries the technology or variant; `Impl` is forbidden.
- A trait exists on the four triggers of the package-layout rule and no other; an in-memory implementation is
  production code under `data/memory`.
- A trait that third parties will implement gets its own crate; a trait that must not be implemented outside
  the crate is sealed with a private supertrait.
- A library wraps a dependency's error in its own error type instead of exposing it through `#[from]`.

### Tests

- A unit test is a sibling file `<name>_tests.rs` declared from the root block as
  `#[cfg(test)] mod jail_tests;`, next to the file it tests. It is a sibling module, so it tests the
  `pub(crate)` surface, which is what the rest of the crate uses. An inline `#[cfg(test)] mod tests {}` is
  allowed only for a genuinely private helper worth testing on its own. The default `mod tests;` child is
  never used: it would create the forbidden `foo.rs` plus `foo/` pair.
- A published crate tests its public API from one integration-test crate `tests/it/` (`tests/it/main.rs` with
  modules), never one binary per file. An internal crate keeps every test under `src` and has no `tests/`.
- Tests that span several crates of a workspace go into a dedicated member crate (`<project>-tests`).
- A shared `test-utils` crate is split per component, because a crate with many dependencies is a hub that
  wrecks incremental builds.

### Cargo's conventional layout

`src/lib.rs`, `src/main.rs`, `src/bin/`, `benches/`, `examples/`, `tests/` and `build.rs` keep their meaning;
nothing else is reserved. `src/lib/` has no special meaning and is never used.
