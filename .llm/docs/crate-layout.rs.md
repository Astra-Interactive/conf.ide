## Rust: layout inside one crate

`arch-package.md` decides which crate a type belongs to. This rule decides where the type goes
inside the crate, and every section of it holds for every crate of the workspace except one: "The
vocabulary" names the modules of a plugin crate (`modules/*`, `instances/*`), borrowed from AspeKt,
the Kotlin plugin this project mirrors, so that a reader of either codebase finds the same thing in
the same place. `library/*` crates are the AstraLibs analog and name their modules after the
concepts of `arch-package.md` (`configuration`, `event`, `lifecycle`, `command`, `permission`)
instead. That is the only difference between the two; nothing else here is narrowed to one of them.

No upstream source bounds files per directory, and the Rust ecosystem tolerates flat crate roots;
the vocabulary below is a team convention, chosen so the tree reads the same in every module.

### The root

`src/` holds `lib.rs` and nothing else, in every crate of the workspace, `library/*` included.
Every type file lives in a module directory. `lib.rs` is an index: crate docs, module blocks with
their `//!` sentence, re-exports, the test declaration.

The first file of a concept creates the concept's directory. There is no intermediate shape where
a concept is a file at the root that a directory is built around later, and no size at which a
concept is too small for one: a module of a single file is normal, a concept at the root is not.
`library/pumpkin/src/` is the worked example — seven concepts, seven directories, `lib.rs` alone at
the root, one of those directories holding one file.

The one exception is the entry crate of a server (`instances/pumpkin`): the host's plugin macro
needs the `Plugin` type at the crate root, so that type stays in `lib.rs` and only it.

Checkable across the workspace in one line, which prints the offending crates and nothing when
there are none:

```sh
find library modules instances -type d -name src \
  -exec sh -c 'ls "$1"/*.rs | grep -qv "lib.rs$" && echo "$1"' _ {} \;
```

### The vocabulary

| Module | AspeKt | Holds |
|---|---|---|
| `di` | `di` | The crate's module struct (`PortalModule`): wiring, file names, lifecycle. Nothing else. |
| `model` | `model` | Plain data: configuration and messages DTOs, entities, value newtypes, outcome enums, the state file. |
| `command` | `command` | The leaf enum, the tree registered with the host, the arguments DTO, the executor. |
| `command/argument` | `argumenttype` (AstraLibs) | Converters from a raw argument string to a model value, and their errors. |
| `command/di` | `command/di` | The command module that binds executors to the slots while enabled. |
| `event` | `event` | Listeners on host events and the code they run on the host. |
| `service` | `service` | Use cases over the state: the service and the errors its operations produce. |
| `storage` | `data`, `krate`, `database` | The repository port, its error, the file or database adapter. |
| `mapping` | `mapping` | Mappers from a model to text or from an error to a reply. |
| `permission` | `plugin/PluginPermission` | The permission nodes of the module and their host registration. |
| `server` | `server` (AstraLibs) | The modules' view of the host: extension traits over host types. Core crates only. |
| `plugin` | `plugin` | Plugin-wide constants such as the namespace. Core crates only. |

A crate uses the modules it needs and no others. One file in a module is normal
(`di/join_message_module.rs`); a module is never created for a file that fits an existing one.
Names outside the table (`util`, `domain`, `presentation`, `types`, `helpers`, `errors`) are not
used: when a type fits none of the rows, the row is missing from this table, not from the crate.

A module never repeats the crate's name (`portal::portal`): clippy's `module_inception` rejects it
and the aggregate belongs in `model`.

### What a model is

A model type has fields and derives. It may have a constructor, trivial accessors (`as_str`,
`command()`), and `Display`. It has no `parse`, no `render`, no I/O, no lock, no `Box<dyn ...>`,
and it depends only on other models, `core-api` and `serde`. A newtype over a string is
`#[serde(transparent)]`; the invariant an admin's input must satisfy is checked once, by the
argument converter, not by the type.

- **Input to model** is an argument converter in `command/argument`: `PortalNameArgument::parse`
  turns the typed word into a `PortalName` or a `PortalNameError`. This is AstraLibs'
  `ArgumentConverter.transform`.
- **Model to text** is a mapper in `mapping`: `CommandTemplateMapper::to_command_line`,
  `PortalReplyMapper::to_create_failure_reply`. This is AspeKt's `*Mapper.toX`.

### Where an error type goes

An error belongs to the operation that produces it, next to its unit of fallibility, never to a
value it merely mentions. `CreatePortalError` is produced by `PortalService::create_portal` and
lives in `service`; `PortalNameError` is produced by the argument converter and lives in
`command/argument`; a storage error lives in `storage`.

### Visibility and paths

Modules are `mod`, not `pub mod`, unless the module is itself a public concept whose name a
caller should type: `portal::storage::YamlPortalRepository`, `portal::command::PortalCommands`.
A private module re-exports at the crate root, so moving a file never changes a caller:
`portal::PortalService` stays `portal::PortalService`. Only the types a caller outside the crate
can name in a signature or construct are re-exported `pub`; the rest are `pub(crate)`, which the
test tree sees. Inside the crate, import by module path (`crate::model::PortalName`), so the
dependency between modules is visible at the top of the file.

The Rust Book (ch. 14.2) makes this the point of `pub use`: it decouples the internal structure
from what the crate presents to its users.

```
modules/portal/src/
├── lib.rs
├── di/                 portal_module.rs
├── model/              portal, portal_name, portal_action, command_template, portal_removal,
│                       portal_state, portal_configuration, portal_messages
├── command/            portal_command, portal_commands, portal_arguments, portal_command_executor
│   ├── argument/       portal_name_argument (+ error), command_template_argument (+ error)
│   └── di/             portal_command_module
├── event/              portal_entry_listener, portal_action_runner
├── service/            portal_service, create_portal_error
├── storage/            portal_repository, portal_storage_error, yaml_portal_repository
├── mapping/            command_template_mapper, portal_reply_mapper
└── permission/         portal_permission
```

Dependencies between the modules form a DAG: `model` imports nothing in-crate; `storage`,
`command/argument` and `mapping` import `model` (and `mapping` the service errors it maps);
`service` imports `model` and `storage`; `command` and `event` import everything below them;
`di` imports everything. A cycle means a type is in the wrong module.

### Why inline module blocks, not `foo.rs` + `foo/`

The Rust Book (ch. 7.5) presents `src/foo.rs` next to `src/foo/` as the idiomatic style. This
project declares modules as inline blocks in `lib.rs` instead. Two reasons: matklad's "Notes on
module system" lists the ambiguities of both file-based styles (`foo/mod.rs` versus `foo.rs`,
files silently absent from the tree), and a `foo.rs` that holds only `mod` lines is a file with
no type in it, which the module-organization rule forbids. `rust-analyzer`'s `ide-assists` crate
uses the same inline-block style for 134 submodules, so it is production-proven. Nested modules
nest their blocks: `pub mod command { mod argument { ... } mod di { ... } ... }`.

The compiler polices the `mod.rs` half: `clippy::mod_module_files` is set to `deny` in the
workspace lints table. It fires only on a file literally named `mod.rs` and stays silent on the
inline-block layout (verified on this workspace); its help text suggests `foo.rs`, which this
rule overrides.

The official style guide's one sentence on modules, "Avoid `#[path]` annotations where possible",
is the other known deviation: the testing rule needs `#[path = "../test/lib.rs"]` once per crate to
place the mirrored test tree, and there is no other way to do it. Both deviations are deliberate;
do not reopen them by quoting the Book or the style guide.

### The test tree

`test/` mirrors `src/` module for module, nested blocks included (`test/command/argument/`,
`test/command/di/`). Mirroring is one-way: a source module without tests gets no test directory,
and `test/support/` mirrors nothing. A type and its test file move in one commit.

### Checklist before adding a file

0. Is the file about to land next to `lib.rs`? Then it is in the wrong place, whatever the crate:
   the only file at the root of a crate is `lib.rs`, and the only type in one is `instances/*`'s
   `Plugin`. Create the concept's directory first. The steps below name the plugin vocabulary; in
   a `library/*` crate they read as that crate's own concepts.
1. Is it plain data with no host, storage or service dependency? `model`.
2. Does it turn an admin's input into a model value? `command/argument`. Does it turn a model or
   an error into text? `mapping`.
3. Does it react to a host event? `event`. Does it run a use case over the state? `service`.
   Does it persist? `storage`. Does it register or name a permission? `permission`.
4. Is it the crate's wiring? `di`. Is it the command wiring? `command/di`.
5. Is it an error? It goes with the operation that produces it.
6. Does a caller outside the crate need it? Only then `pub use` it at the root, or make the module
   `pub` if the module name is part of the vocabulary.
7. Does the move create a cycle between modules? Then one type is in the wrong module.
