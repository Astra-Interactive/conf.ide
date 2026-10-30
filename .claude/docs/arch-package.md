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
- **core**: the project's common unit for what is not worth a unit of its own;
- **feature**: another word for a sub-context (`gui`, `payment`); a feature unit is any unit of one.

### Units

1. A project has these kinds of unit:
   - **sub-context units** of a context (`modules/command`, `modules/gui/api`, `modules/data/exposed`);
   - an **entry-point unit** (`instances/bukkit`, `androidApp`): the classes the platform constructs (a
     plugin's main class; an Android `Application` and its `Activity`) and `RootModule`, nothing else. Nothing
     depends on it. An application may have several, one per platform or a debug instance;
   - **`core`**: the common unit for what is not worth a unit of its own: config, translation and permission
     models, shared helpers, shared coroutine scopes, small platform pieces. It holds no use case and no
     repository, and depends on no feature unit. It may be split by platform (`core/api`, `core/bukkit`) and, in an app
     with Compose, into a design-system unit (`core/ui`);
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
   (`modules/command`, `modules/event-bukkit`). Storage that several sub-contexts use, or a technology heavy
   enough for its own build (Exposed, Room), is a contracts unit plus one unit per technology (`data/dao`,
   `data/exposed`). Storage of one sub-context in files or in memory is a technology package of that
   sub-context (`jail/file`).
5. **App** (Kotlin Multiplatform, Android): a feature others depend on is an `api` unit (contracts, the
   models in their signatures, the `util` rules of those models, stubs) plus an `impl` unit (the implementation and its use cases). Platform
   code is a source set of the unit, never a unit.
6. A use case that several sub-contexts need lives in the `api` unit of the sub-context that owns the
   operation (rating a player is the rating menu's operation: `gui/api`); the others depend on that `api`. In an
   app, the `usecase` package of the owner's `api` unit holds the use case's interface and the `usecase` package
   of its `impl` unit the `Default…` implementation; the
   others call the interface. When no owner can be named, the agent asks.
7. A unit's directory never holds another unit: a split sub-context's directory is a container with no build
   file and no sources (`gui/api`, `gui/bukkit`).
8. Every unit carries a `README.md` of one sentence stating its responsibility. A sentence that does not fit is
   the signal to split the unit.
9. A small piece that does not deserve a unit lives in `core` as a package named for what it is
   (`core/coroutine`), never as a tiny unit.

### Concepts and kinds

Every source path reads `<unit root>[/<concept>[/<sub-concept>]]/<kind>[/<sub-kind>]/<File>`, the sub-kind for
Compose's `composable` only (Concepts and kinds 1). A kind directly under the unit root holds what the whole
unit shares: its DI module, a model or a helper several concepts use (`…command.model.UsageCommandException`).
Two places hold files without a kind: the concept package of a unit that is wholly one technology (2), and the
root package of the entry-point unit, which holds the classes the platform constructs beside its `di`.

1. A package holds files or packages, never both: a concept holds packages, a kind holds files. A one-file
   kind package is normal. A kind package exists only when it has a file. Compose's `composable` may hold
   sub-packages (`screen`, `component`, `layout`, a project's own words) instead of files; the Kotlin Compose
   rule says when. Two packages hold both: the concept package of a unit that is wholly one technology
   (Implementation exception, 2) and the root package of the entry-point unit (the classes the platform
   constructs beside `di`).

   ```
   …gui.api.rating.change.model.RatingPlayer         data it returns
   …gui.api.rating.change.usecase.AddRatingUseCase   operation others call
   …data.dao.rating.api.RatingRepository             storage contract, in the concept it stores
   ```

2. **Implementation exception.** A unit is wholly one technology when it exists to implement contracts on one
   storage or platform technology (`data/exposed` on Exposed, `gui/bukkit` on Bukkit); the helper libraries it
   uses (cache4k) do not change that, and their implementations sit beside the others, named by their library
   (`Cache4kRatedUsersCache`). In such a unit (`data/exposed`), the concept package holds the implementations
   directly, and beside them the classes only they use (`RefreshingCache`). Everything else of that technology
   sits in kind packages (`table`, `entity`, `model`, `util`, `database`, `di`) at the level that uses it:
   inside the concept when only that concept uses it, under the unit root when several do. A technology
   package inside another unit (`jail/file`, `core/cache/cache4k`) holds only code built on that technology:
   implementations of contracts and the classes they use, or generic code that units of two sub-contexts need.

   ```
   …data.exposed.rating.ExposedRatingRepository
   …data.exposed.rating.CacheRefreshingRatingRepository
   …data.exposed.rating.RefreshingCache
   …data.exposed.rating.table.UserRatingTable
   …data.exposed.database.RatingDatabase
   …data.exposed.di.ExposedModule
   ```

3. Kinds:

   | Kind | Holds |
   |---|---|
   | `api` | contracts of the concept: interfaces other files or units call |
   | `model` | the level's own types: data classes, sealed results, error families (one file each), events, config models |
   | `usecase` | operations named `<Verb><Object>UseCase` |
   | `util` | the level's functions: extensions (`<Subject>Ext.kt`), the rules of the model among them (`arch-domain.md`), and top-level functions; never a class or an `object` declaration (an anonymous `object :` of a bridge is allowed, `arch-package.kt.md`) |
   | `di` | the DI modules of the level (see the DI rule) |
   | entry-point kinds | named in the project's and the framework's vocabulary: `command`, `event`, `route`, `job`, `service` (run on a timer or its own lifecycle); for UI, see below |
   | `theme` | Compose only: the values (timings, spacing, tokens) several composables of the level share, as an `object` of values; in the design-system unit also the theme itself, its `CompositionLocal`s and the `@Composable` theme function (`compose.kt.md`) |
   | `warmup` | a task the platform runs once at start to seed state (`RatingCacheWarmUp`), in the unit of the state it seeds |
   | `migration` | code that converts stored data or config from an old format, inside the concept it migrates (`core/settings/migration/ConfigSnakeCaseMigration.kt`) |
   | `error` | classes that turn a failure into the user's reply, in the unit of the mechanism that fails (`command/error/CommandExceptionHandler.kt`) |
   | technology packages | implementations of a contract and the classes they use, or generic code that units of two sub-contexts need, named by the library it uses (`exposed`, `krate`, `ktor`, `room`, `cache4k`) or by `file`, `memory` |
   | `stub` | a stub or preview implementation of a contract that other units need |
   | `table`, `entity`, `database` | only in a unit that is wholly one technology: its tables, its row entities, its connection |

4. **UI vocabulary is derived, not fixed.** `composable` and `theme` mean Kotlin Compose and are used only
   there (`theme` holds the values several composables of a level share; the Kotlin Compose rule says what
   else a Compose unit holds); `viewmodel` means an Android-style view model, with or without Compose. For any
   other UI framework the names come from the framework's own classes and from the words the project already
   uses. AstraRating uses AstraLibs' `Menu` inside a `gui` sub-context, with its own words: `gui` (menus),
   `slot` (menu parts), `context` (`SlotContext`), `component` (the holder of a menu's state), `model`
   (`RatingSlotKey`). A router, the class through which the code opens a screen or a menu, is a contract like
   any other: its interface in `api` of the unit that owns navigation (`gui/api/router/api/GuiRouter`), its
   implementation beside the other implementations in the platform or `impl` unit
   (`gui/bukkit/router/BukkitGuiRouter`).
5. **The project's word wins.** When a project already names a kind with its own word (`component` for a
   state holder), new files of that kind use it, unless the word is forbidden below or plural (9).
6. **A file belongs to the sub-context of what it does, then to a kind by mechanism.** `RatingCacheWarmUp`
   seeds the rating cache at start, so it belongs to `data` (`warmup`) and reaches the server through
   AstraLibs' `PlatformServer`. A listener of a platform event stays in its event unit even when it only loads
   a cache (AstraRating's `LoginEvent`, a name from before the `…Listener` rule); a failure handler sits with the mechanism that fails.
7. **`model` and `util` live at every level.** A model or a function lives in the `model` or `util` of the
   level that uses it, even as one file (`integration/papi/placeholder/model/PapiConfig.kt`). A higher level's
   `model` or `util` holds only what several lower levels share; a rule of a model that two units use lives in
   the `util` of the model's own unit. `core` has the same concept → kind shape (`core/settings/model`,
   `core/util`).
8. **Before `util`, ask in order.** Does the file implement, wrap or narrow a contract? Beside the other
   implementations. Does the platform run it at a moment (start, failure, tick)? The kind of that mechanism in
   the unit it serves. Is it generic code that units of two sub-contexts need? `core`, in the technology
   package of the library it is built on (`core/cache/cache4k/<Class>.kt`), moved there once a unit of a
   second sub-context needs it; until then it sits beside its only user, and the `api` and platform units of
   one sub-context share it through the `api` unit. Only when every answer is no and the file holds functions,
   a rule of the model included, is it `util`. `util` and `model` are never the place for a class no kind
   fits: the agent asks the user and proposes a word.
9. Naming: a concept is named in the project's words, singular, lowercase, one segment. Every package name is
   singular, except an inherently plural concept (`news`); which concept is plural is the reviewer's call.
10. Never a package name: `domain`, `application`, `infrastructure`, `presentation`, `ui`, `controller`,
   `entrypoint`, `impl`, `internal`, `repository`, `valueobject`, `aggregate`, `factory`, `exception`, `dto`,
   `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`, `in`, `out`, `spi`,
   `inbound`, `outbound`, `validation`. `table`, `entity` and `database` are allowed only in a unit
   that is wholly one technology. The list applies to packages inside a unit: a unit's root package follows its
   unit path, and a unit name may keep a project's existing word (`data/dao` → `…data.dao`, `payment/impl` →
   `…payment.impl`).

### Contracts and implementations

- An interface exists on four triggers and no other: another unit calls it; two or more implementations exist
  or one is known to come; an inner part declares what it needs from an outer one; a test must replace it with
  a fake, which is allowed only for a contract over I/O or the platform. Pure logic, entities and use cases get
  no interface, except an app's use case that another unit calls (Units 6). Whether one is known to come and
  whether a test must replace it are the reviewer's call.
- A contract sits in the `api` package of its concept. Two kinds keep their interface with their
  implementation, named by what the class is: an app use case's interface sits in `usecase` (Units 6), and a
  state holder's interface in the project's state-holder kind (`component`, `viewmodel`), beside its
  `Default…` implementation (`gui/api/rating/players/component/RatingPlayersComponent`, `players` an old
  plural name); in an app, when another unit calls it, its interface sits in that kind of the owner's `api`
  unit and `Default…` in `impl`, as a use case's (`payment/api/offer/component/OfferComponent`,
  `payment/impl/offer/component/DefaultOfferComponent`). A contract's implementation sits in the technology's
  package or unit, under the same concept, and is named by its technology or variant
  (`ExposedRatingRepository`, `InMemoryJailRepository`, `CacheRefreshingRatingRepository`). `Impl`, the `I`
  prefix and the `Interface` suffix are forbidden. `database`, `network`, `local` and `remote` are not
  technology names. An implementation with no technology and no variant, such as an app's use case or a state
  holder behind its interface, is named `Default<Interface>` (`DefaultAddRatingUseCase`).
- A cache over storage is part of storage, never of its consumer. One that wraps the whole contract is
  another implementation beside it (`CacheRefreshingRatingRepository`). One that caches part of it gets its own
  contract in the storage concept's `api` and its implementation in the technology unit (`RatedUsersCache`,
  `Cache4kRatedUsersCache`).
- Dependency direction: the first table of `arch-context.md`. In short: implementations depend on contracts
  and `model`; use cases on contracts, `model` and `util`; entry points on use cases, contracts, `model` and
  `util`; nothing outside its unit depends on an entry point, and inside it UI kinds depend on each other as
  `arch-context.md` says; `di` depends on everything, and only another `di` and the classes the platform
  constructs in the entry-point unit depend on it: a DI module takes DI modules through its constructor. A use
  case and a contract import no platform or framework type; a state holder's interface may import its UI
  framework (Decompose's `ComponentContext`, `Value`), nothing else of the platform.
- No pass-through: an entry point may call a contract directly. A use case exists only when the flow has more
  than one step: it reads from a contract, applies a model rule and acts on the outcome, or it combines two or
  more contracts. A use case never calls another use case.

### Files

- A file holds one type family: a sealed hierarchy with its variants, or a data class with the data classes
  nested in it. A class with behaviour always has its own file, even a private helper of one class
  (`RefreshingCache` is not inside `CacheRefreshingRatingRepository.kt`). A class with behaviour is any class
  or object with a function body of its own (not a data class's generated members, not an enum's entries); a
  design-system component's public `<Component>Defaults` object is the one that sits in its component's file
  (`compose.kt.md`). A file is split only when it passes 400 lines.
- A data class that is a property type of exactly one class is nested in it. A type that is a property of two
  or more classes, or is returned to another class, is top-level in `model`.
- Every error family is its own file in `model`, a sealed error with all its subclasses or a single error
  class: an error a contract names in the `model` of the contract's level, any other in the `model` of the
  level that uses it, even one used by one class. There is no `exception` package.
- Extension functions live in `util/<Subject>Ext.kt` of the level that uses them (`KPlayerExt.kt`), never in
  the type's own file. A file that declares a class holds no top-level function; a Compose composable file
  declares no class, so an extension of a type the project does not declare that only it uses is `private` in
  it (`compose.kt.md`). A function is never an `object` used as a namespace (a `theme` object holds values,
  not functions; Compose's two exceptions: the design-system theme object's `@Composable get()` of a
  `CompositionLocal`, Material's `MaterialTheme.colorScheme`, and a design-system component's public
  `<Component>Defaults`), and there is no `Helper`, `Util` or `Manager` class.
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
concept/kind shape, the naming of implementations, the dependencies between units. A checker checks what a rule
states as a fixed name, number or shape; everything else in these rules is the reviewer's call, the platform and
framework imports of `model`, `api` and `usecase` included. The checker is not written yet; until it exists, the
skill's checklist is answered by hand and the final message says so.

**Load the `package-layout` skill before the first new file of a task.**
