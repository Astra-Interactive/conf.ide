## Package layout

**Before the first new file of a task, load the `package-layout` skill, record `BASE=$(git rev-parse HEAD)` and
print the planned tree.** The skill holds the procedure, the thresholds and the examples. This rule holds what
the finished tree must look like; the Kotlin and Rust rules add the language mechanics.

Terms used below:

- **build unit**: a Gradle module or a Cargo crate;
- **package**: a directory of sources (a Kotlin package, a Rust module);
- **DI module**: a wiring class such as `LinkModule` or `RootModule`;
- **concept**: a package named with a singular domain noun (`link`, `code`, `player`, `nickname`);
- **kind**: a package named with a role word from the table below (`api`, `model`, `database`, `di`);
- **entry point**: the class the platform manifest names (plugin main class, `Application`) or `main`.

### Shape

Every source path reads `<unit root>/<concept>[/<sub-concept>…]/<kind>/<File>`. A unit that is one feature has
its kinds directly under its root package; in a refactor, its old domain packages of 3 or more files stay as
concepts next to those kinds (see Existing code).

1. Concept packages hold only packages. Kind packages hold only files. A one-file kind package is normal.

   ```
   link/api/LinkApi.kt              contract other units call
   link/model/UnlinkResponse.kt     data it returns
   link/code/api/CodeApi.kt         sub-concept: the same shape one level down
   link/code/internal/CodeApiImpl.kt
   ```

2. Every concept package the task creates is split into kinds, whatever its size.
3. Three unit roots are the only places where a file lies outside a kind package:
   - the entry point, in the root package of the unit that starts the application, next to its `di/`
     (`AstraRating.kt` + `di/RootModule.kt`);
   - a unit whose path ends in `api` and that holds only contracts and the models in their signatures: the unit
     is the `api` kind, so the files lie in its root package (`feature/profile/api` →
     `…feature.profile.api.ProfileRepository`, `…feature.profile.api.Profile`);
   - a unit that owns one kind (`modules/command`, `gui/bukkit`, `core/database`): a feature's concept package in
     it holds that kind's files directly (`…command.nickname.NickCommand`).
4. Name a new concept with the singular noun the task uses for the feature (`nickname`). Package names are
   lowercase, singular, one segment; words are concatenated (`usecase`, `viewmodel`, `permissiongroup`).
5. Layers (`domain/`, `data/`, `presentation/`) appear only when the skill's layer trigger fires, the user asks
   for them, or the concept already has them.

### Kinds

The first row whose condition the file meets decides its kind.

| Kind | The file |
|---|---|
| `fake` | lives in the test tree: a hand-written fake or fixture of the concept's contracts |
| `di` | is a DI module, including `RootModule`, or a factory only the wiring calls |
| `database` | imports a database library: tables, rows, DAO implementations, migrations |
| `network` | imports an HTTP, WebSocket or RPC client, or declares wire DTOs |
| `storage` | saves state the program writes itself to files or key-value stores (YAML state, krate, DataStore) |
| `config` | declares or loads what an admin or user edits: config file models, translations |
| `argument` | converts a typed command argument into a model value, and the concept has ≥ 2 such converters |
| `command` | declares a chat or CLI command: executor, registration, tab completion, a single argument converter |
| `event` | listens to platform events |
| `menu` | is a game-server menu a player clicks through: inventory GUI, book or chat menu |
| `composable` | is Compose UI |
| `view` | is UI of another toolkit (Android View, terminal UI) |
| `viewmodel` | holds the state of one screen or menu and handles its intents, with its state and event types |
| `permission` | declares permission nodes and registers them |
| `discord`, `luckperms`, … | adapts one external system, and ≥ 2 files of the concept do; a single adapter is `internal` |
| `mapping` | converts between two representations and has ≥ 2 callers |
| `usecase` | is one operation that decides something or combines ≥ 2 contracts |
| `check`, `policy`, … | ends in a role noun no row names, shared by ≥ 2 files of the concept |
| `api` | declares a contract: an interface, a trait, an abstract class |
| `model` | declares domain data: values, entities, sealed results, errors |
| `impl` | implements a contract without a technology row above and is public: another unit, or a project that uses the published library, constructs it or names it (Rust names this kind `imp`: `impl` is a keyword) |
| `internal` | implements a contract without a technology row above and stays inside its unit, or helps the concept's other files |
| `util` | is a stateless helper with no domain noun in its name, used by ≥ 2 kinds or ≥ 2 concepts |

The package name tells the truth about visibility: everything in `internal/` is `internal` / `pub(crate)`, and a
public implementation lives in `impl/` (`core-bukkit/…/player/impl/BukkitKPlayer.kt` in a library whose plugins
create Bukkit players).

`models`, `dto`, `utils`, `errors`, `exception`, `service`, `manager`, `controller`, `repository`, `dao`,
`ui`, `gui`, `presentation` are not kind names, and neither are the layer words `domain` and `data` used as kinds:
the skill's replacement table gives the row to use. A role no row describes goes through the skill's new-kind
procedure and is reported in the final message.

### Files

A file holds one type family. The sealed type comes first:

```kotlin
// model/LinkResponse.kt: the sealed interface and every variant, one file
sealed interface LinkResponse {
    data class Linked(val player: LinkedPlayer) : LinkResponse
    data object CodeExpired : LinkResponse
}
```

- A sealed type or an enum and all its variants are one file named after the parent.
- A data class that is a property type of exactly one class is nested in it (`Order.Shipping`), however many
  other files read it or pass it on.
- A result a function returns to another class (a sealed outcome, a summary, a page of items) is its own family
  in `model/`, never nested in the class that returns it: `RenameUseCase` returns `model/RenameResult.kt`, so the
  tree shows what the feature can answer.
- The companion, private helpers and the extensions every client uses stay in the type's file.
- A file is split only above 400 lines, by moving a whole group of variants or extensions into a second file of
  the same package; one variant or one nested class never gets a file of its own.

### Visibility

Decide the visibility while writing the declaration. Everything is private to its build unit (Kotlin `internal`,
Rust `pub(crate)`) except:

- the entry point;
- declarations another build unit uses: the contents of an `api` unit, a DI module another unit constructs, the
  models in their signatures, the implementations in `impl/`. In a published library, a declaration the projects
  that use the library need counts as used by another unit.

A unit nothing depends on (an app, an instance, a plugin jar, a binary crate) makes only its entry point public.
Class members are `private` unless another class uses them. Public is Kotlin's default, so a public Kotlin
declaration carries no modifier: the keyword `public` is never written, and the explicit API mode
(`explicitApi()`) is never switched on. The Rust check `unreachable_pub` is switched on only in crates the task
creates.

### Build units

Decide the build unit of every new file before writing the first one. The number of units the project has now
is not a criterion.

1. A file of a kind that an existing unit owns goes to that unit, under a concept named after the feature:
   persistence to the unit that owns the database schema, commands to the command unit, menus to the GUI unit.
2. In a project with more than one build unit besides its entry-point units, a new feature gets its own unit
   when it has entry points of its own (commands, screens, menus, listeners) or state of its own (a new table,
   file or store) with operations on it. This holds even when its UI is shown inside an existing screen or menu:
   the existing unit then calls the new unit's contract, and the persistence still goes to the owner unit (rule 1).
   - an app feature is always an `api` + `impl` pair (`feature/profile/api`, `feature/profile/impl`);
   - a plugin feature is one unit until another unit must call or implement its contracts, or its platform code
     must be isolated (≥ 2 platforms, logic tested without the server API, or the user asks). Then it is split
     into `<feature>/api` (the contracts and the models in their signatures) + `<feature>/impl` (the
     platform-free implementation), plus `<feature>/<platform>` for each platform whose code must be isolated.
   - a unit's directory never holds another unit: a split feature's directory is a container with no build file
     and no sources (`modules/onboarding/api` + `modules/onboarding/impl`, never a `modules/onboarding` unit with
     `api/` inside it).
3. A change with no entry point and no state of its own (a new subcommand, a new field an existing screen shows)
   joins the unit that holds its concept.

A new unit's root package is its path, 1:1. The skill has the criteria in full and the scaffold steps.

When the user asks to re-lay out existing code, every existing unit is decided again by these rules, like every
package: a unit in the wrong shape is split, merged or moved, and the final message names each one.

### Existing code

- Never move, rename or delete a file that existed before the task, unless the user asks.
- When the user asks to re-lay out existing code, every file counts as new, and every old package that groups
  files under a domain noun (a sub-concept, or a top-level package of a one-feature unit) is decided again by its
  size. One of 3 or more files stays, with its files split into kinds even when they are all one kind
  (`limbo-packet/src/play/model/`, `plugin/file/internal/`). One of 1 or 2 files is dissolved into its parent's
  package of that kind (`onboarding/check/command/CheckCommand.kt` → `onboarding/command/`); it stays only to
  mirror a sibling unit where the same concept is kept (`core-bukkit/…/location/mapping/` next to
  `core/…/location/{api,model}/`).
- Edit an old file only where the new code plugs in: a new call, a new branch, a new constructor argument, a new
  line of wiring, and a new nested type, variant or property of an old type, which goes into the old type's file.
  Leave every other old line as it is: no renames, no code moved out into new files, no reformatting, and no
  style rules (`no-it`, naming, ordering) applied to lines the task does not otherwise need.
- New files follow these rules inside old packages too: a new kind package next to old loose files is correct.
- When the build unit already names a role with another word (`commands/`, `utils/`, `impl/`, `exception/`), new
  files of that role use that word, in the parent package and in new sub-concepts alike (`nickname/impl/`, not
  `nickname/database/`, in a unit whose DAO implementations live in `impl/`). Only the word is borrowed, not the
  old shape: the new contract still goes to `nickname/api/`, and nothing new lies loose.
- The final message lists the old files the rules would move, and where.

### Before the final message

List the files the task added since `BASE` and answer the skill's checklist in one line per item. A finding is
fixed by moving the new file, never an old one.

**Load the `package-layout` skill before the first new file of a task.**
