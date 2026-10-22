## Package layout

**Before the first new file of a task, load the `package-layout` skill, record `BASE=$(git rev-parse HEAD)` and
print the planned tree.** The skill holds the procedure, the decision tests, the checklist and the worked
examples. This rule holds what the finished tree must look like; `arch-package.kt.md` and `arch-package.rs.md`
add the language mechanics; `arch-domain.md` holds the domain building blocks; `arch-context.md` holds what
crosses between units.

Terms used below:

- **unit**: a build unit, a Gradle module or a Cargo crate;
- **context**: the business area a project or a part of it serves (`rating` in AstraRating, `jail` in AspeKt);
- **sub-context**: a part of a context with its own reason to change: an entry mechanism (`command`,
  `event`, `gui`), an integration with an external system (`integration-papi`), storage (`data`);
- **concept**: a package named for a thing in the project's words (`rating`, `jail`, `player`);
- **kind**: a package named for what its files are (`api`, `model`, `usecase`, `util`, `di`, `command`, `menu`);
- **entry point**: a class the platform calls (a command, a listener, a menu, a route, a screen, a task);
- **core**: the project's common unit for what is not worth a unit of its own.

### Units

1. A project has these kinds of unit:
   - **sub-context units** of a context (`modules/command`, `modules/gui/api`, `modules/data/exposed`);
   - an **entry point** (`instances/bukkit`, `androidApp`): the platform main class and `RootModule`, nothing
     else. Nothing depends on it. An application may have several, one per platform or a debug instance;
   - **`core`**: the common unit for what is not worth a unit of its own: config, translation and permission
     models, shared helpers, shared coroutine scopes, small platform pieces. It holds no use case and no
     repository, and depends on no feature unit. It may be split by platform (`core/api`, `core/bukkit`);
   - a **`<context>/contract`** unit for the wire types a server and its client share;
   - a **tooling unit** with no product code: `build-logic`, an `xtask` crate, a `<feature>/fake` unit.
   A published library (AstraLibs) is a dependency of a project, not one of its units.
2. A context is cut into sub-context units. The author decides the cut; the sub-context kinds in Terms are
   examples, not a closed list. An agent proposes the cut and asks the user (see the skill); without an
   answer, new code goes as a package into an existing unit. An agent never proposes to merge an existing cut;
   a merge the user asks for goes through the approval of Existing code.
3. Paths: in a project with one context, `modules/<sub-context>` (AstraRating: `modules/command`,
   `modules/gui`, `modules/data`); with several contexts, `modules/<context>`, and
   `modules/<context>/<sub-context>` once the author cuts it. A unit's root package follows the unit path in
   the project's existing convention (the Kotlin companion gives the mechanics).
4. **Plugin** (separate Gradle JVM builds per platform): when the author splits a sub-context by platform
   (the agent asks, as in 2), it becomes an `api` unit and one unit per platform (`gui/api`, `gui/bukkit`,
   `gui/forge`). The `api` unit holds the platform-free code other units call: models, use cases, contracts
   and their platform-free implementations. The platform unit holds everything that imports the platform, and
   platform-free code that only it uses (`RatingSlotKey`). There is no `impl` unit: in a plugin it would add
   modules and make nothing easier. A sub-context that is not split is one unit, platform imports included
   (`modules/command`, `modules/event-bukkit`). Storage is a contracts unit plus one unit per technology (`data/dao`, `data/exposed`).
5. **App** (Kotlin Multiplatform, Android): a feature others depend on is an `api` unit (contracts, the
   models in their signatures, stubs) plus an `impl` unit (the implementation and its use cases). Platform
   code is a source set of the unit, never a unit.
6. A use case that several sub-contexts need lives in the `api` unit of the sub-context that owns the
   operation (rating a player is the rating menu's operation: `gui/api`); the others depend on that `api`. When
   no owner can be named, the agent asks.
7. A unit's directory never holds another unit: a split sub-context's directory is a container with no build
   file and no sources (`gui/api`, `gui/bukkit`).
8. Every unit carries a `README.md` of one sentence stating its responsibility. A sentence that does not fit is
   the signal to split the unit.
9. A small piece that does not deserve a unit lives in `core` as a package named for what it is
   (`core/coroutine`), never as a tiny unit.

### Concepts and kinds

Every source path reads `<unit root>[/<concept>[/<sub-concept>]]/<kind>/<File>`. A kind directly under the
unit root holds what the whole unit shares: its DI module, a model or a helper several concepts use
(`…command.model.UsageCommandException`).

1. A concept package holds only packages. A kind package holds only files. A one-file kind package is normal.
   A kind package exists only when it has a file.

   ```
   …gui.api.rating.api.RatingPlayersRepository     contract
   …gui.api.rating.model.RatedPlayer               data it returns
   …gui.api.rating.usecase.RatePlayerUseCase       operation others call
   …data.dao.rating.api.RatingRepository           storage contract, in the concept it stores
   ```

2. **Implementation exception.** In a unit that is wholly one technology's implementation
   (`data/exposed`), the concept package holds the implementations directly. Everything else of that
   technology sits in kind packages (`table`, `entity`, `model`, `database`, `di`) at the level that uses it:
   inside the concept when only that concept uses it, under the unit root when several do. A technology
   package inside another unit (`jail/file`) holds only implementations.

   ```
   …data.exposed.rating.ExposedRatingRepository
   …data.exposed.rating.CachedRatingRepository
   …data.exposed.rating.RefreshingCache
   …data.exposed.rating.table.UserRatingTable
   …data.exposed.database.RatingDatabase
   …data.exposed.di.ExposedModule
   ```

3. Kinds:

   | Kind | Holds |
   |---|---|
   | `api` | contracts of the concept: interfaces other files or units call |
   | `model` | the level's own types: data classes, sealed results, errors (one file each), events, config models |
   | `usecase` | operations named `<Verb><Object>UseCase` |
   | `util` | the level's functions: extensions (`<Subject>Ext.kt`), the rules of the model among them (`arch-domain.md`), and top-level functions; never a class or an `object` |
   | `di` | the DI modules of the level (see the DI rule) |
   | entry-point kinds | named in the project's and the framework's vocabulary: `command`, `event`, `route`, `job`, `service` (run on a timer or its own lifecycle); for UI, see below |
   | `warmup` | a task the platform runs once at start to seed state (`RatingCacheWarmUp`), in the unit of the state it seeds |
   | `migration` | code that converts stored data or config from an old format, inside the concept it migrates (`core/settings/migration/ConfigSnakeCaseMigration.kt`) |
   | `error` | classes that turn a failure into the user's reply, in the unit of the mechanism that fails (`command/error/CommandExceptionHandler.kt`) |
   | technology packages | an implementation of a contract, or code built on one library, named by the library it uses (`exposed`, `krate`, `ktor`, `room`, `cache4k`) or by `file`, `memory` |
   | `stub` | a stub or preview implementation of a contract that other units need |

4. **UI vocabulary is derived, not fixed.** `composable` and `viewmodel` mean Kotlin Compose and an Android
   style view model, and are used only there. For any other UI framework the names come from the framework's
   own classes and from the words the project already uses. AstraRating uses AstraLibs' `Menu` inside a
   `gui` sub-context, with its own words: `gui` (menus), `slot` (menu parts), `context` (`SlotContext`),
   `component` (the holder of a menu's state), `router`, `model` (`RatingSlotKey`).
5. **The project's word wins.** When a project already names a kind with its own word (`component` for a
   state holder), new files of that kind use it, unless the word is forbidden below.
6. **A file belongs to the sub-context of what it does, then to a kind by mechanism.** `RatingCacheWarmUp`
   seeds the rating cache at start, so it belongs to `data` (`warmup`) and reaches the server through
   AstraLibs' `PlatformServer`. A listener of a platform event stays in its event unit even when it only loads
   a cache (`LoginEvent`); a failure handler sits with the mechanism that fails.
7. **`model` and `util` live at every level.** A model or a function lives in the `model` or `util` of the
   level that uses it, even as one file (`integration/papi/model/PapiConfig.kt`). A higher level's `model` or
   `util` holds only what several lower levels share. `core` has the same concept → kind shape
   (`core/settings/model`, `core/util`).
8. **Before `util`, ask in order.** Does the file implement, wrap or narrow a contract? Beside the other
   implementations. Does the platform run it at a moment (start, failure, tick)? The kind of that mechanism in
   the unit it serves. Is it generic code that two units need? `core`, in the technology package of the library
   it is built on (`core/cache/cache4k/RefreshingCache.kt`). Only when every answer is no and the file holds
   functions, a rule of the model included, is it `util`. `util` and `model` are never the place for a class no
   kind fits: the agent asks the user and proposes a word.
9. Naming: a concept is named in the project's words, singular, lowercase, one segment. Every package name is
   singular, except an inherently plural concept (`news`).
10. Never a package name: `domain`, `application`, `infrastructure`, `presentation`, `ui`, `controller`,
   `entrypoint`, `impl`, `internal`, `repository`, `valueobject`, `aggregate`, `factory`, `exception`, `dto`,
   `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`, `in`, `out`, `spi`,
   `inbound`, `outbound`, `validation`. `table` and `entity` are allowed only inside a technology's
   implementation. The list applies to packages inside a unit: a unit's root package follows its unit path,
   and a unit name may keep a project's existing word (`data/dao` → `…data.dao`, `monetization/impl` →
   `…monetization.impl`).

### Contracts and implementations

- An interface exists on four triggers and no other: another unit calls it; two or more implementations exist
  or one is known to come; an inner part declares what it needs from an outer one; a test must replace it with
  a fake, which is allowed only for a contract over I/O or the platform. Pure logic, entities and use cases get
  no interface.
- A contract sits in the `api` package of its concept. Its implementation sits in the technology's package or
  unit, under the same concept, and is named by its technology or variant (`ExposedRatingRepository`,
  `InMemoryJailRepository`, `CachedRatingRepository`). `Impl`, the `I` prefix and the `Interface` suffix are
  forbidden. `database`, `network`, `local` and `remote` are not technology names.
- A cache over storage is part of storage, never of its consumer. One that wraps the whole contract is
  another implementation beside it (`CachedRatingRepository`). One that caches part of it gets its own
  contract in the storage concept's `api` and its implementation in the technology unit (`RatedUsersCache`,
  `Cache4kRatedUsersCache`).
- Dependency direction: the first table of `arch-context.md`. In short: implementations depend on the
  contracts they implement and `model`; entry points on use cases, contracts and `model`; nothing depends on an
  entry point; `di` depends on everything and nothing depends on it. A use case and a contract import no
  platform or framework type.
- No pass-through: an entry point may call a contract directly. A use case exists only when the flow has more
  than one step: it reads from a contract, applies a model rule and acts on the outcome, or it combines two or
  more contracts. A use case never calls another use case.

### Files

- A file holds one type family: a sealed hierarchy with its variants, or a data class with the data classes
  nested in it. A class with behaviour always has its own file, even a private helper of one class
  (`RefreshingCache` is not inside `CachedRatingRepository.kt`). A file is split only above about 400 lines.
- A data class that is a property type of exactly one class is nested in it. A type that is a property of two
  or more classes, or is returned to another class, is top-level in `model`.
- Every error type is its own file in `model`: an error a contract names in the `model` of the contract's
  level, any other in the `model` of the level that uses it, even one used by one class
  (`modules/command`: `…command.model.UsageCommandException`). There is no `exception` package.
- Extension functions live in `util/<Subject>Ext.kt` of the level that uses them (`KPlayerExt.kt`), never in
  the type's own file. A file that declares a class holds no top-level function. A function is never an
  `object` used as a namespace, and there is no `Helper`, `Util` or `Manager` class.
- Wire types: a server and its client in one repository share them through the `<context>/contract` unit;
  otherwise a route's types live with the route and a client's in its technology package.
- A domain type carries no kind suffix (`Rating`, not `RatingModel`). A technology representation carries the
  technology word (`UserRatingTable`, `RatingRow`). A use case carries `UseCase`; a contract carries the word
  for what it is (`RatingRepository`).

### Existing code

- **Re-layout needs approval.** Merging, moving, renaming or deleting anything that exists (a unit, a package,
  a file, a class name, DI wiring) happens only after the user approved a printed tree "before → after". A request such as "fix the issues" is not that
  approval. Without it the rules apply to new files only.
- **Re-layout does not change mechanisms.** A move changes packages, imports and the DI lines the move forces,
  nothing else. The project's mechanisms stay as they are: its `Lifecycle` objects, how listeners start
  (`val job = flowEvent(...)`), its krates, its DI wiring. The DI rule applies to the DI modules a task
  creates; existing wiring that breaks it (a flat `RootModule`) stays. Replacing a
  mechanism is a separate task the user asks for.
- Edit an old file only where the new code plugs in: a new call, a new branch, a new constructor argument, a
  new line of wiring, a new variant or property of an old type.
- New files follow this rule next to old packages named otherwise, except that the project's own word for a
  kind wins (Concepts and kinds 5). A new error goes to `model/`, not to an old `exception/`.
- The final message lists the old files the rule would move, and where.

### Enforcement

Every line of this rule that a tool can check is meant to be checked in the build: package names, the
concept/kind shape, the naming of implementations, the imports allowed in `model`, `api` and `usecase`, the
dependencies between units. The skill names the checker; until it exists, the skill's checklist is answered by
hand and the final message says so.

**Load the `package-layout` skill before the first new file of a task.**
