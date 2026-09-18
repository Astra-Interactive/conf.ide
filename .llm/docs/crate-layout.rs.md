## Rust: layout inside one crate

`arch-package.md` decides which crate a type belongs to. This rule decides where the type goes
inside that crate, for the common case where the crate *is* one bounded context and "top level =
business concept" has already been spent on the crate's name.

The ecosystem tolerates flat roots: `sqlx-core`, `hir-def` and `helix-view` keep 18-26 files next
to `lib.rs`, and no upstream style guide, API guideline or clippy option bounds the number of files
in a directory. Every number in this rule is therefore a team convention, chosen for readability,
not borrowed from an authority.

### The root

`src/` holds `lib.rs` and at most **one** type file: the keystone the crate hangs from. In a
feature crate that is the module struct (`portal_module.rs`); in a shared crate it is the defining
value (`plugin_namespace.rs`). Everything else lives in a sub-module.

The module struct earns the slot because it imports from every sub-module; inside any one of them
it would make that module depend on all its siblings. If two files compete for the slot, neither
is the keystone and both move.

Exempt: a crate with six type files or fewer is one concept and stays flat (`join-message`,
`core-pumpkin`). The rule binds when the crate grows past that.

`lib.rs` is an index, not a home: crate docs, module blocks, re-exports, the test declaration.
No type and no free function is declared in it.

Checkable in one line: `ls src/*.rs` prints `lib.rs` and at most one more name.

### The `model` module

Every crate past the exemption has a `model` module: the plain data of the concept. Entities and
value objects with their parse errors (`Portal`, `PortalName`, `PortalNameError`), enums that name
an outcome (`ZoneRemoval`, `ReturnDestination`), and the state that is written to disk
(`PortalState`). A model type depends on other model types, on `core-api` and on `serde`; never on
a host crate, a repository, a service or a configuration store. A type with a `Box<dyn ...>`, a
lock or an I/O call is not a model.

`model` is the one module named for a kind of code rather than a concept. Inside a one-concept
crate the plain data types all change for the same reason, the shape of the concept, so grouping
them by kind and grouping them by reason to change is the same grouping. That argument does not
extend to `service`, `dto`, `errors` or `utils`: a service and a listener change for different
reasons, and an error belongs to whatever produces it (see below).

### Naming the other sub-modules

A sub-module is named for a **sub-concept** or for the **boundary it sits on**, a word a
maintainer or an admin already uses: `zone`, `registry`, `selection`, `trigger`, `protection`,
`storage`, `command`, `configuration`. `storage` and `command` are not layers in disguise: they
name who is on the other side of the boundary, and every crate has a different set of them.

Forbidden, because they name the kind of code and every crate would grow the identical set:
`domain`, `application`, `infrastructure`, `service`, `dto`, `types`, `errors`, `utils`,
`helpers`. None of the mid-size crates surveyed (`axum`, `bevy_ecs`, `tokio`, `cargo`,
`rust-analyzer`) has a layer directory inside a crate; in Rust a layer is a crate boundary.

Equally forbidden is a module that repeats the crate's name: `portal::portal::Portal` adds no word
to the vocabulary, and clippy's `module_inception` rejects it. The aggregate goes to `model`.

The admission test is written down, not felt: the module block's `//!` doc states in one sentence
what changes it. A module whose doc would read "types used by the others" is visual grouping and
is not admitted. A module is born with at least two files; one file is not a concept, leave it
where it is until it has a neighbour.

Vertical slices are idiomatic when a concept has many parallel operations: `cargo::ops` and
`ide-assists::handlers` keep one file per operation. `create/`, `remove/`, `list/` is allowed
when the operations stop fitting one service.

### Where an error type goes

An error belongs to the operation that produces it, next to its unit of fallibility, never to a
value it merely mentions. `CreatePortalError` is produced by `PortalService::create_portal` and
lives in the service's module, not with `PortalName` and not at the root. A value's own parse
error is a model type and sits next to the value in `model`. A storage error sits in `storage`.

### Visibility and paths

Sub-modules are `mod`, not `pub mod`, unless the module is itself a public concept whose name a
caller should type: `portal::storage::YamlPortalRepository`, `portal::command::PortalCommands`.
A private module re-exports at the crate root, so moving a file never changes a caller:
`portal::PortalService` stays `portal::PortalService`. Only the types a caller outside the crate
can name in a signature or construct are re-exported `pub`; the rest are `pub(crate)`, which the
test tree sees.

The Rust Book (ch. 14.2) makes this the point of `pub use`: it decouples the internal structure
from what the crate presents to its users. The counterweight is aturon's: the re-export block is
the only place the public API can be read, so it is complete and the private items are not in it.

```
modules/portal/src/
├── lib.rs                  index: module blocks, re-exports, the test declaration
├── portal_module.rs        keystone: the crate's wiring and lifecycle
├── model/                  the portal, its name, its action and command template, the removal
│                           outcome, the state file
├── registry/               creating, removing and listing portals: the service and its error
├── storage/                persistence across restarts: the port, its error, the YAML adapter
├── configuration/          what the admin controls: the yml, the chat replies, the permission nodes
├── command/                the `/portal` tree (public: the root registers it)
└── trigger/                running a portal's action on the move event
```

### Why inline module blocks, not `foo.rs` + `foo/`

The Rust Book (ch. 7.5) presents `src/foo.rs` next to `src/foo/` as the idiomatic style. This
project declares modules as inline blocks in `lib.rs` instead. Two reasons: matklad's "Notes on
module system" lists the ambiguities of both file-based styles (`foo/mod.rs` versus `foo.rs`,
files silently absent from the tree), and a `foo.rs` that holds only `mod` lines is a file with
no type in it, which the module-organization rule forbids. `rust-analyzer`'s `ide-assists` crate
uses the same inline-block style for 134 submodules, so it is production-proven.

The compiler polices the `mod.rs` half: `clippy::mod_module_files` is set to `deny` in the
workspace lints table. It fires only on a file literally named `mod.rs` and stays silent on the
inline-block layout (verified on this workspace), so it costs nothing; its help text suggests
`foo.rs`, which this rule overrides.

The official style guide's one sentence on modules, "Avoid `#[path]` annotations where possible",
is the other known deviation: the testing rule needs `#[path = "../test/lib.rs"]` once per crate to
place the mirrored test tree, and there is no other way to do it. Both deviations are deliberate;
do not reopen them by quoting the Book or the style guide.

### The test tree

`test/` mirrors `src/` module for module; the keystone mirrors at the test root
(`test/portal_module.rs`). Mirroring is one-way: a source module without tests gets no test
directory, and `test/support/` mirrors nothing. A type and its test file move in one commit.

### Smell, not a limit

More than about seven entries on one level, files plus module blocks, means a concept is missing.
It is a signal to look, never a quota: do not split a coherent module to get under it, do not fill
one to reach it.

### Checklist before adding a file to a crate

1. Is it the keystone? Only then does it go next to `lib.rs`.
2. Is it plain data of the concept with no host, storage or service dependency? Then `model`.
3. Otherwise, which sub-concept or boundary does it belong to? That module. If none fits and the
   crate has more than six type files, the concept is missing: name it, give it a `//!` sentence.
4. Is it an error? It goes with the operation that produces it; a parse error of a value goes to
   `model` next to the value.
5. Does a caller outside the crate need it? Only then `pub use` it at the root, or make the module
   `pub` if the module name is part of the vocabulary.
6. Does the move create a cycle between modules (`registry` importing `storage` and `storage`
   importing `registry`)? Then one type is in the wrong module.
