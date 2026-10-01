## Rust: crate layout mechanics

The package-layout rule says which package a file goes to. This rule says how a crate expresses it: exactly one
module root, `src/lib.rs`, through which every module and every test is connected.

### One module root

- `src/` holds `lib.rs` and nothing else. A binary crate adds `src/main.rs`, which only calls the library:

  ```rust
  // src/main.rs
  fn main() -> std::process::ExitCode {
      limbo::di::run()
  }
  ```

- Every other file lives in a kind directory, from the first file of its concept on: `src/model/whitelist_entry.rs`,
  never `src/whitelist_entry.rs`.
- `lib.rs` declares every module as nested inline blocks that mirror the directories. The compiler resolves
  `mod profile_client;` inside `mod profile { mod api { … } }` to `src/profile/api/profile_client.rs`.
- Each file is a private module; its types are re-exported at the kind module, so paths read like Kotlin
  packages: `crate::profile::api::ProfileClient`, never `crate::profile::api::profile_client::ProfileClient`.
- `lib.rs` holds only crate docs (`//!`), crate attributes, `mod` blocks with one `//!` sentence each, `use` /
  `pub use` lines and the test block. No types and no functions, except a type the host requires at the crate root
  (a plugin macro's `Plugin` type).
- Blocks are in alphabetical order; inside a block the `mod` lines come first, then the re-exports.
- There is no `mod.rs`, no `foo.rs` next to a `foo/` directory, and no `#[path]` except the one on the test block.

A crate that is one concept, with a three-file sub-concept:

```rust
// src/lib.rs
//! Lets only listed players join and keeps the list in `whitelist.yml`.
#![deny(unreachable_pub)]
#![deny(clippy::mod_module_files, clippy::self_named_module_files)]

pub(crate) mod api {
    //! The contract the command and the listener read the list through.
    mod whitelist_repository;
    pub(crate) use whitelist_repository::WhitelistRepository;
}

pub(crate) mod command {
    //! `/whitelist add`, `remove` and `list`.
    mod whitelist_command;
    pub(crate) use whitelist_command::WhitelistCommand;
}

pub mod di {
    //! Wiring of the crate; the server instance constructs [`WhitelistModule`].
    mod whitelist_module;
    pub use whitelist_module::WhitelistModule;
}

pub(crate) mod event {
    //! Rejects a joining player who is not on the list.
    mod join_listener;
    pub(crate) use join_listener::JoinListener;
}

pub(crate) mod model {
    //! A whitelist entry and the ways changing the list can fail.
    mod whitelist_entry;
    mod whitelist_error;
    pub(crate) use whitelist_entry::WhitelistEntry;
    pub(crate) use whitelist_error::WhitelistError;
}

pub(crate) mod profile {
    //! Resolves a player name to a profile through the Mojang API.
    pub(crate) mod api {
        mod profile_client;
        pub(crate) use profile_client::ProfileClient;
    }
    pub(crate) mod model {
        mod player_profile;
        pub(crate) use player_profile::PlayerProfile;
    }
    pub(crate) mod network {
        mod mojang_profile_client;
        pub(crate) use mojang_profile_client::MojangProfileClient;
    }
}

pub(crate) mod storage {
    //! Reads and writes the list in `whitelist.yml`.
    mod yaml_whitelist_repository;
    pub(crate) use yaml_whitelist_repository::YamlWhitelistRepository;
}

#[cfg(test)]
#[path = "../test"]
mod test {
    mod command {
        mod whitelist_command_test;
    }
    mod fake {
        mod fake_whitelist_repository;
        pub(crate) use fake_whitelist_repository::FakeWhitelistRepository;
    }
}
```

A new file costs two lines in `lib.rs` (`mod x;` and its re-export) and a new directory two more. When `lib.rs`
would pass about 300 lines (about 100 files), the crate is split into crates by concept; a crate the task creates
is split at plan time.

In an existing crate whose modules are declared in `mod.rs` or `foo.rs` files, a new file inside such a module is
declared in that module's file; new top-level modules are declared in `lib.rs`. The final message names the
modules that still use `mod.rs`.

### Visibility

- **R-V1.** Items are `pub(crate)` by default. An item is `pub` only when another crate uses it, and then its kind
  module and the concept modules above it are `pub mod`. Only concept, layer, `api`, `model` and `di` modules may
  ever be `pub mod`; every other kind module is `pub(crate) mod`.
- **R-V2.** An `unused import` or `dead_code` warning on a `pub(crate)` item means it is not wired yet: wire it
  into its DI module in the same task, or delete it. A warning is never silenced by widening `pub(crate)` to `pub`,
  by turning a `pub(crate) mod` into `pub mod`, or with `#[allow]`.
- Struct fields are private; a constructor function builds the value.
- A crate the task creates carries the three lint attributes shown above, in `lib.rs`. An existing crate keeps its
  lints; the task follows R-V1 in the lines it writes.

### What goes in one file

- An `enum` and the payload structs used only by its variants are one file named after the enum
  (`model/whitelist_error.rs`).
- A type a function returns to another module (an outcome enum, a summary struct) is its own file in `model/`,
  never declared in the file of the function that returns it (`model/add_entry_outcome.rs`).
- A struct is one file with its inherent `impl`, its trait impls and the small types only it uses (a settings
  struct it alone reads).
- A trait is one file with its blanket impls; each implementation lives in its own kind (`storage/`, `network/`).
- A type is never declared inside a function body.
- A file is named after its primary type in `snake_case` and is split only above 400 lines, by a whole group of
  items.

### Tests

- Tests live in `test/`, next to `src/`, mirroring it directory for directory. A source file holds no
  `#[cfg(test)]`, no `mod tests` and no `#[test]`.
- The test tree is declared once, as the last item of `src/lib.rs`: `#[cfg(test)] #[path = "../test"] mod test
  { … }`, with nested blocks exactly like the source tree. A test file is named after the source file with the
  `_test` suffix: `test/command/whitelist_command_test.rs` tests `src/command/whitelist_command.rs`.
- Test files import what they test by path (`use crate::command::WhitelistCommand;`) and see `pub(crate)` items,
  the analog of Kotlin `internal`. A private function that needs its own test becomes `pub(crate)`.
- A fake lives in `fake/` inside the concept of the contract it replaces: `test/fake/fake_whitelist_repository.rs`
  for the crate's own `api`, `test/profile/fake/fake_profile_client.rs` for the sub-concept's. A fake other
  crates need lives in a `<name>-test-support` crate, pulled in as a dev-dependency, instead of a copy per crate.
- Integration tests that use only the public API live in Cargo's `tests/` directory.
