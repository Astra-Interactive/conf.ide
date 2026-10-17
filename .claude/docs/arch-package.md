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
2. A context is cut into sub-context units. The author decides the cut; the kinds above are examples, not a
   closed list. An agent proposes the cut and asks the user (see the skill); without an answer, new code goes
   as a package into an existing unit. An existing cut is never merged.
3. Paths: in a project with one context, `modules/<sub-context>` (AstraRating: `modules/command`,
   `modules/gui`, `modules/data`); with several contexts, `modules/<context>/<sub-context>`. A unit's root
   package is the project's base package plus the unit path.
4. **Plugin** (separate Gradle JVM builds per platform): a sub-context that has platform code or that other
   units call is split into an `api` unit and one unit per platform (`gui/api`, `gui/bukkit`, `gui/forge`).
   The `api` unit holds everything platform-free: models, use cases, contracts and their platform-free
   implementations. The platform unit holds everything that imports the platform. There is no `impl` unit: in
   a plugin it would add modules and make nothing easier. A sub-context with no platform split is one unit
   (`modules/command`). Storage is a contracts unit plus one unit per technology (`data/dao`, `data/exposed`).
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

Every source path reads `<unit root>/<concept>[/<sub-concept>]/<kind>/<File>`.

1. A concept package holds only packages. A kind package holds only files. A one-file kind package is normal.
   A kind package exists only when it has a file.

   ```
   …gui.api.rating.api.RatingPlayersRepository     contract
   …gui.api.rating.model.RatedPlayer               data it returns
   …gui.api.rating.usecase.RatePlayerUseCase       operation others call
   …data.dao.rating.api.RatingRepository           storage contract, in the concept it stores
   ```

2. **Implementation exception.** In a unit, or a package, that is wholly one technology's implementation
   (`data/exposed`), the concept package holds the implementations directly, and everything else of that
   technology sits in kind packages beside them: `table`, `entity`, `model`, `database`, `di`.

   ```
   …data.exposed.rating.ExposedRatingRepository
   …data.exposed.rating.CachedRatingRepository
   …data.exposed.rating.RefreshingCache
   …data.exposed.table.UserRatingTable
   …data.exposed.database.RatingDatabase
   …data.exposed.model.DbRatingConfiguration
   ```

3. Kinds:

   | Kind | Holds |
   |---|---|
   | `api` | contracts of the concept: interfaces other files or units call |
   | `model` | the level's own types: data classes, sealed results, errors (one file each), events, config models |
   | `usecase` | operations named `<Verb><Object>UseCase` |
   | `util` | extension functions (`<Subject>Ext.kt`) and helpers of the level |
   | `di` | the DI module of the level (see the DI rule) |
   | entry-point kinds | named in the project's and the framework's vocabulary: `command`, `event`, `route`, `job`, `service`; for UI, see below |
   | technology packages | an implementation of a contract, named by the library it uses (`exposed`, `krate`, `ktor`, `room`) or by `file`, `memory` |
   | `stub` | a stub or preview implementation of a contract that other units need |

4. **UI vocabulary is derived, not fixed.** `composable` and `viewmodel` mean Kotlin Compose and an Android
   style view model, and are used only there. For any other UI framework the names come from the framework's
   own classes and from the words the project already uses. AstraRating uses AstraLibs' `Menu` inside a
   `gui` sub-context: `gui/menu` (menus), `gui/component` (reusable menu parts), `gui/context` (`SlotContext`),
   `gui/feature` (the holder of a menu's state), `gui/model` (`RatingSlotKey`).
5. **The project's word wins.** When a project already names a kind with its own word (`feature` for a state
   holder), new files of that kind use it, unless the word is forbidden below.
6. **A file belongs to the sub-context of what it does, then to a kind by mechanism.** `RatingCacheWarmUp`
   warms the rating cache, so it belongs to `data`, even though the platform runs it on start.
7. **`model` and `util` live at every level.** A model or a helper lives in the `model` or `util` of the level
   that uses it, even as one file (`integration/papi/model/PapiConfig.kt`). A higher level's `model` or `util`
   holds only what several lower levels share.
8. Naming: a concept is named in the project's words, singular, lowercase, one segment. Every package name is
   singular, except an inherently plural concept (`news`).
9. Never a package name: `domain`, `application`, `infrastructure`, `presentation`, `ui`, `controller`,
   `entrypoint`, `impl`, `internal`, `repository`, `valueobject`, `aggregate`, `factory`, `exception`, `dto`,
   `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`, `in`, `out`, `spi`,
   `inbound`, `outbound`, `validation`. `table` and `entity` are allowed only inside a technology's
   implementation. A unit name may keep a project's existing word (`data/dao`).

### Contracts and implementations

- An interface exists on four triggers and no other: another unit calls it; two or more implementations exist
  or one is known to come; an inner part declares what it needs from an outer one; a test must replace it with
  a fake, which is allowed only for a contract over I/O or the platform. Pure logic, entities and use cases get
  no interface.
- A contract sits in the `api` package of its concept. Its implementation sits in the technology's package or
  unit, under the same concept, and is named by its technology or variant (`ExposedRatingRepository`,
  `InMemoryJailRepository`, `CachedRatingRepository`). `Impl`, the `I` prefix and the `Interface` suffix are
  forbidden. `database`, `network`, `local` and `remote` are not technology names.
- A cache is another implementation of the contract that wraps one, beside it.
- Dependency direction: `model` depends on nothing of its level; `api` depends on `model`; `usecase` depends on
  `api` and `model`; implementations and entry points depend on contracts, use cases and `model`; nothing
  depends on an entry point; `di` depends on everything and nothing depends on it. A use case and a contract
  import no platform or framework type.
- No pass-through: an entry point may call a contract directly. A use case exists only when the flow has more
  than one step: it reads from a contract, applies a model rule and acts on the outcome, or it combines two or
  more contracts. A use case never calls another use case.

### Files

- A file holds one type family: a sealed hierarchy with its variants, or a data class with the data classes
  nested in it. A class with behaviour always has its own file, even a private helper of one class
  (`RefreshingCache` is not inside `CachedRatingRepository.kt`). A file is split only above about 400 lines.
- A data class that is a property type of exactly one class is nested in it. A type that is a property of two
  or more classes, or is returned to another class, is top-level in `model`.
- Every error type is its own file in the `model` of the level that uses it, even one used by one class
  (`command/model/UsageCommandException.kt`). There is no `exception` package.
- Extension functions default to `util/<Subject>Ext.kt` of the level that uses them (`KPlayerExt.kt`); they go
  into the type's own file only when they are part of the type. Helpers are top-level functions, never an
  `object` used as a namespace.
- Wire types: a server and its client in one repository share them through the `<context>/contract` unit;
  otherwise a route's types live with the route and a client's in its technology package.
- A domain type carries no kind suffix (`Rating`, not `RatingModel`). A technology representation carries the
  technology word (`UserRatingTable`, `RatingRow`). A use case carries `UseCase`, a contract its role word
  (`RatingRepository`).

### Existing code

- **Re-layout needs approval.** Merging, moving, renaming or deleting an existing unit or package happens only
  after the user approved a printed tree "before → after". A request such as "fix the issues" is not that
  approval. Without it the rules apply to new files only.
- **Re-layout does not change mechanisms.** A move changes packages, imports and DI lines only. The project's
  mechanisms stay as they are: its `Lifecycle` objects, how listeners start (`val job = flowEvent(...)`), its
  krates, its DI tree. Replacing a mechanism is a separate task the user asks for.
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
