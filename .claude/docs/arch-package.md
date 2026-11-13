## Package layout

This file says where a file goes. `arch-domain.md` says what a type is and what it holds. `arch-context.md`
says what crosses a unit boundary. A `.kt.md` or `.rs.md` file says how the language writes a rule of its shared
file and states no rule of its own. The skill is the order of steps and states no rule.

**Load the `package-layout` skill before the first new file of a task.**

Terms used below:

- **unit**: a build unit, a Gradle module or a Cargo crate;
- **context**: the business area a project or a part of it serves (`rating`, `jail`);
- **sub-context**: a part of a context with its own reason to change: an entry mechanism (`command`, `event`,
  `gui`), an integration with an external system (`integration-<system>`), storage (`data`), a capability with
  data or operations of its own (`vote`);
- **concept**: a package named for a thing in the project's words (`rating`, `jail`, `player`);
- **kind**: a package named for what its files are (`api`, `model`, `usecase`, `util`, `di`, `command`, `menu`);
- **entry point**: a class the platform calls (a command, a listener, a menu, a route, a screen, a task);
- **core**: the common unit for what two or more units use and that no single unit's concept names (Units 1);
- **feature**: another word for a sub-context (`gui`, `payment`); a feature unit is any unit of one.

### Units

1. A project has these kinds of unit:
   - **sub-context units** of a context (`modules/command`, `modules/gui/api`, `modules/data/exposed`);
   - an **entry-point unit** (`instances/bukkit`, `androidApp`): the classes the platform constructs (a
     plugin's main class; an Android `Application` and its `Activity`), `RootModule` and the `model` and `error`
     kinds of its framework failure type, nothing else. Nothing depends on it. An application may have several,
     one per platform or a debug instance;
   - **`core`**: the product-wide configuration, translation and permission models (a configuration a single unit
     loads from its own file is that unit's model), coroutine scopes (Rust: a `TaskScope`, `async.rs.md`), platform
     pieces as packages named for what they are (`core/coroutine`), never as tiny units, generic classes (no model
     type of the project in their signatures), `util` functions over platform and library types, framework
     registration interfaces. It holds no use case and no repository, depends on no feature unit, and takes nothing
     before its second consumer. It may be split by platform (`core/api`, `core/bukkit`) and, in an app with
     Compose, into a design-system unit (`core/ui`);
   - a **`<context>/contract`** unit for the wire types a server and its client share, and a **`<context>/server`**
     unit beside it for what serves the routes;
   - a **tooling unit** with no product code: `build-logic`, an `xtask` crate, a Kotlin `<feature>/fake` unit.
   A published library is a project of its own: a capability in it is a package in the unit of its platform scope
   (`core`, `core-bukkit`), and a unit only when it brings dependencies the others must not inherit; its units
   switch explicit API mode on (`arch-package.kt.md`) and have no `api`/`impl` split.
2. A context is cut into sub-context units. The author decides the cut; the sub-context kinds in Terms are
   examples, not a closed list. New code is a new capability when no unit of the project names its concept yet and
   it brings a stored concept, a use case or entry points of its own; code for a concept the project has goes where
   that concept's code is. The capability's unit holds its use cases, the rules of its concept (`util`) and
   the models that storage does not hold; the units that show or trigger it take them from there. Its entry
   points go to the unit that holds that mechanism's entry points and no use case (`modules/command`,
   `gui/bukkit`), where the project has one, else stay in the capability; its storage goes where the project
   keeps storage (`data/dao`), else into a technology package of the capability's platform-free unit; an
   integration with a dependency of its own is `integration-<system>`. An agent never proposes to merge an existing cut; a merge the
   user asks for goes through the approval of Existing code.
3. Paths: in a project with one context, `modules/<sub-context>` (`modules/command`, `modules/gui`,
   `modules/data`); with several contexts, `modules/<context>`, and `modules/<context>/<sub-context>` once the
   author cuts it. In a plugin, a capability that other units call keeps its platform-free code in
   `modules/<capability>/api` (other units may depend only on an `api` unit) and its own platform code, if any,
   in `modules/<capability>/<platform>`; a capability nothing else calls is one unit, `modules/<capability>`,
   split only as Units 4 says. In an app a new capability is a feature laid out by Units 5. A unit's root
   package (in Rust, its crate name) follows the unit path in the project's existing convention (the language
   companions give the mechanics).
4. **Plugin** (a separate build per platform: Gradle JVM builds, or Rust crates per host framework): a sub-context
   with code for two or more platforms, or with platform code beside platform-free code that other units call,
   becomes an `api` unit and one unit per platform (`gui/api`, `gui/bukkit`, `gui/forge`). The `api` unit holds
   the platform-free code other units call: models, use cases, contracts and their platform-free implementations.
   The platform unit holds everything that imports the platform, and platform-free code that only it uses (a local
   use case or a model of its own). There is no `impl` unit: in a plugin it would add modules and make nothing
   easier. A sub-context that is not split is one unit, platform imports included (`modules/command`,
   `modules/event-bukkit`). Storage that several sub-contexts use, or a technology heavy enough for its own build
   (Exposed, Room), is a contracts unit plus one unit per technology (`data/dao`, `data/exposed`). Storage of one
   sub-context in files or in memory is a technology package of that sub-context (`jail/file`).
5. **App** (Kotlin Multiplatform, Android, a server or a bot, and every Rust project that is not a plugin): a
   feature others depend on is an `api` unit (contracts, the models in their signatures, the `util` rules of those
   models, stubs) plus an `impl` unit (the implementation and its use cases); its UI lives in a UI unit (`impl-ui`)
   beside `impl`. Platform code is a source set of the unit (in Rust, code under a target `cfg`), never a unit.
6. A use case that several production units need lives in the `api` unit of the sub-context that owns the operation
   (rating a player is the rating menu's operation: `gui/api`); the others depend on that `api`. In an app, the
   `usecase` package of the owner's `api` unit holds the use case's interface and the `usecase` package of its
   `impl` unit the `Default…` implementation; the others call the interface. A new use case of a concept the
   project already has goes beside that concept's use cases; a new capability's use cases live in its `api` unit.
   Placement follows responsibility and production consumers, not the absence of platform imports or the name
   `…UseCase`.
   A plugin use case used only by one platform unit stays in that unit's `usecase`; an app's implementation
   stays in `impl` or, when the feature has one, its `impl-ui` unit, including its UI implementation.
   An unsplit owner's use case stays in its unit.
   Contracts, models, errors and functions used only by that implementation stay with it. The `api` package of a
   concept is a place for contracts inside any unit; it does not require an `api` unit. Types exposed by a shared
   contract stay with that contract, including nested and generic signature types; dependencies needed by shared
   API behaviour stay with that behaviour. Count actual calls, implementations and signature dependencies, not
   imports or declared Gradle dependencies. Tests, test fakes and construction by the entry point's DI alone do
   not justify promoting production code to an API unit. For published libraries, external consumers are part
   of the contract even when absent from this checkout.
7. A unit's directory never holds another unit: a split sub-context's directory is a container with no build
   file and no sources (`gui/api`, `gui/bukkit`).
8. Every unit carries a `README.md` of one sentence stating its responsibility. A sentence that does not fit is
   the signal to split the unit.

### Concepts and kinds

Every source path reads `<unit root>[/<concept>[/<sub-concept>]]/<kind>[/<sub-kind>]/<File>`, the sub-kind for
Compose's `composable` only (Concepts and kinds 1). A unit holds its kinds at its root. A task creates a concept
package for a thing the unit does not yet name when it adds, for that thing, three or more files of two or more
kinds; an aggregate (`arch-domain.md`) and a stored concept of the storage contracts unit always get one. Files
already placed are never regrouped; only the files the task adds are counted. Two places hold files without a kind:
the concept package of a unit that is wholly one technology (2), and the root package of the entry-point unit,
which holds the classes the platform constructs beside its `di`.

1. A package holds files or packages, never both: a concept holds packages, a kind holds files. A one-file
   kind package is normal. A kind package exists only when it has a file. Compose's `composable` may hold
   sub-packages (`screen`, `component`, `layout`, a project's own words) instead of files; the Kotlin Compose
   rule says when. Two packages hold both: the concept package of a unit that is wholly one technology
   (Implementation exception, 2) and the root package of the entry-point unit (the classes the platform
   constructs beside `di` and the `model` and `error` kinds of its framework failure type).

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

   The platform unit of `core` (`core/bukkit`, `CorePlatform`) has the same placement exception: its
   implementations and their helpers may sit directly in a concept (`item/ItemStackSerializer`). Its root
   still holds packages only; explicit `api`, `model`, `util` and `di` packages keep their usual rules.
   The tables of `arch-context.md` apply to it unchanged. Assembly of a configured serializer format that
   registers concrete implementations belongs to `di`, not `util`.

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
   | `usecase` | operations (`arch-domain.md`, Use case) |
   | `util` | the level's functions: extensions (`<Subject>Ext.kt`), the rules of the model among them (`arch-domain.md`), and top-level functions; none has a receiver or parameter whose type is a contract of the project (a function type that stands in for one included) or calls one; never a class or an `object` declaration (an anonymous `object :` of a bridge is allowed, `arch-package.kt.md`; in Rust an extension is a method of an `impl <Type>` block in `util/<type>_ext.rs`, or of a `<Type>Ext` trait when another crate declares the type, `arch-package.rs.md`) |
   | `di` | the DI modules of the level (see the DI rule) |
   | entry-point kinds | named in the project's and the framework's vocabulary: `command`, `event`, `route`, `job`, `service` (run on a timer or its own lifecycle); for UI, see below |
   | `theme` | Compose only: the values (timings, spacing, tokens) several composables of the level share, as an `object` of values; in the design-system unit also the theme itself, its `CompositionLocal`s and the `@Composable` theme function (`compose.kt.md`) |
   | `warmup` | a task the platform runs once at start to seed state (`RatingCacheWarmUp`), in the unit of the state it seeds |
   | `migration` | code that converts stored data or config from an old format, inside the concept it migrates (`core/settings/migration/ConfigSnakeCaseMigration.kt`) |
   | `error` | classes that turn a failure into the user's reply, in the unit of the mechanism that fails (`command/error/CommandExceptionHandler.kt`) |
   | technology packages | implementations of a contract and the classes they use, or generic code that units of two sub-contexts need, named by the library it uses (`exposed`, `krate`, `ktor`, `room`, `cache4k`) or by `file`, `memory` (Rust also `system`, `arch-package.rs.md`) |
   | `stub` | a stub or preview implementation of a contract that other units need |
   | `fake` | test implementations that script failures or record calls; in test sources or `testFixtures` (in Rust, the crate's `test/` tree, or its `fixture/` tree behind the `fake` feature), or in `commonMain` of a dedicated Kotlin `<feature>/fake` unit; consumed only by tests |
   | `table`, `entity`, `database` | only in a unit that is wholly one technology: its tables, its row entities, its connection |
   | role kind | a class no row above fits (it does no I/O, keeps no state between calls, is not a pure computation that a `util` function would be, and the platform does not call it), in a kind named by the last word of its class name (`PacketCodec` → `codec`, `PacketRegistry` → `registry`, `PlaceholderParser` → `parser`); a last word that is a fixed kind, a technology, one of the project's entry-point or UI words, or one of `Manager`, `Helper`, `Controller`, `Util`, `Utils` renames the class; the word is added to the project's linter config in the same change (Kotlin `roleKinds`; Rust `role-kinds` in `[workspace.metadata.klibs-rules]` or `[package.metadata.klibs-rules]`) |

4. **UI vocabulary is derived, not fixed.** `composable` and `theme` mean Kotlin Compose and are used only
   there (`theme` holds the values several composables of a level share; the Kotlin Compose rule says what
   else a Compose unit holds); `viewmodel` means an Android-style view model, with or without Compose. For any
   other UI framework the names come from the framework's own classes and from the words the project already
   uses (AstraLibs' `Menu`: `gui` for menus, `slot` for menu parts, `context`, `component` for the holder of a
   menu's state). A router, the class through which the code opens a screen or a menu, is a contract like
   any other: its interface in `api` of the unit that owns navigation (`gui/api/router/api/GuiRouter`, in a
   `router` concept that also holds `model/GuiDestination` and `usecase/OpenGuiUseCase`), its implementation
   beside the other implementations in the platform or `impl` unit (`gui/bukkit/router/BukkitGuiRouter`).
5. **The project's word wins.** When a project already names a kind with its own word (`component` for a
   state holder), new files of that kind use it, unless the word is forbidden below or plural (9).
6. **A file belongs to the sub-context of what it does, then to a kind by mechanism.** `RatingCacheWarmUp`
   seeds the rating cache at start, so it belongs to `data` (`warmup`); in a plugin built on AstraLibs it reaches
   the server through AstraLibs' `PlatformServer`. A listener of a platform event stays in its event unit even
   when it only loads a cache; a failure handler sits with the mechanism that fails.
7. **`model` and `util` live at every level.** A model or a function lives in the `model` or `util` of the
   level that uses it, even as one file (`integration/<system>/placeholder/model/PlaceholderConfig.kt`). A higher level's
   `model` or `util` holds only what several lower levels share; where a rule of a model that two units use
   lives: `arch-domain.md`, Rules live in `util`. `core` has the same concept → kind shape (`core/settings/model`,
   `core/util`).
8. **Before `util`, ask in order.** Does the file implement, wrap or narrow a contract? Beside the other
   implementations. Does the platform run it at a moment (start, failure, tick)? The kind of that mechanism in the
   unit it serves. Is it generic code that units of two sub-contexts need? `core`, in the technology package of the
   library it is built on (`core/cache/cache4k/<Class>.kt`); the `api` and platform units of one sub-context share
   it through the `api` unit. Only when every answer is no and the file holds functions, a rule of the model
   included, is it `util`. `util` and `model` are never the place for a class no kind fits: it takes the role kind,
   asked last.

   **Before `event`, ask the same way.** `event` holds listeners and platform event types, nothing else: a
   class a listener uses is not an entry point. Does the platform or the project's scheduler run it? The kind
   of that mechanism, never `event`: `service` or the project's word for it (`job`) for a timer or a lifecycle
   of its own, `warmup` for a task run once at start. Does it keep state between calls and touch no platform?
   Storage: a contract in `api`, its implementation in `memory` (`RatingCache` with `InMemoryRatingCache`).
   Does it keep state and act on the platform (entities it spawned, packets it sent)? A contract in `api` in
   model types, its implementation in the technology package named after the platform library, or directly in
   the concept when the unit is wholly that technology (2). Is it a flow of several steps (it reads a
   contract, applies a rule, acts on the outcome)? A use case: the listener turns platform values into model
   values before the call and applies the platform effect to the result after it (`KillEventListener` with
   `LowerKillerRatingUseCase`). Otherwise it is a platform effect or a conversion with no state: functions in
   `util`, an extension of the platform type. When none fits, the class takes the role kind.
9. Naming: a concept is named in the project's words, singular, lowercase, one segment. Every package name is
   singular; the plural words a project keeps are in its linter configuration (`pluralConcepts`; Rust
   `plural-concepts`).
10. Never a package name: `domain`, `application`, `infrastructure`, `presentation`, `ui`, `controller`,
   `entrypoint`, `impl`, `internal`, `repository`, `valueobject`, `aggregate`, `factory`, `exception`, `dto`,
   `type`, `enum`, `dao`, `common`, `shared`, `helpers`, `misc`, `port`, `adapter`, `in`, `out`, `spi`,
   `inbound`, `outbound`, `validation`. `table`, `entity` and `database` are allowed only in a unit
   that is wholly one technology. The list applies to packages inside a unit: a unit's root package follows its
   unit path, and a unit name may keep a project's existing word (`data/dao` → `…data.dao`, `payment/impl` →
   `…payment.impl`).

### Contracts and implementations

- An operation contract interface exists on five triggers and no other: another unit calls it; two or more
  implementations exist, a second one written in the same task counting; an inner part declares what it needs
  from an outer one; a test written in the same task replaces it with a fake, which is allowed only for a
  contract over I/O or the platform; an entry point or a use case needs state that is kept between calls (a cache
  of what was sent, cooldowns, open sessions), which is storage (Units 4): its contract in `api`, its
  implementation in `memory` (in an app, `memory` of the `impl` unit). Pure logic, entities and use cases get
  no interface, except an app's use case that another unit calls (Units 6).
- A polymorphic serialization data shape may use an interface in `model` when it declares only read-only
  data properties, with no functions, property implementations or behaviour. Inherited members satisfy the
  same restrictions; a companion of constants is allowed. Its properties carry scalar or
  model values. This is a data representation, not an operation contract; it does not permit model
  dependencies on `api`.
- A domain contract sits in the `api` package of its concept. Two kinds keep their interface with their
  implementation, named by what the class is: an app use case's interface sits in `usecase` (Units 6), and a
  state holder's interface in the project's state-holder kind (`component`, `viewmodel`), beside its
  `Default…` implementation (`gui/api/rating/list/component/RatingListComponent`); in an app, when another
  unit calls it, its interface sits in that kind of the owner's `api` unit and `Default…` in `impl`, or in
  `impl-ui` when the feature has one (Units 6) (`payment/api/offer/component/OfferComponent`,
  `payment/impl-ui/offer/component/DefaultOfferComponent`). A contract's implementation sits in the technology's
  package or unit, under the same concept, and is named by its technology or variant
  (`ExposedRatingRepository`, `InMemoryJailRepository`, `CacheRefreshingRatingRepository`). Test fakes use
  the `fake` kind and the test-sharing layout of the language companion (`arch-package.kt.md`,
  `arch-package.rs.md`); preview stubs use `stub`.
  `Impl`, the `I` prefix and the `Interface` suffix are forbidden. `database`, `network`, `local` and `remote` are not
  technology names. An implementation with no technology and no variant, such as an app's use case or a state
  holder behind its interface, is named `Default<Interface>` (`DefaultAddRatingUseCase`).
- A framework registration interface stays in the package of its mechanism (`route`, `command`, or the
  project's equivalent), including in mixed `core` when several units use it. It connects implementations
  to the framework during setup; it is not a domain operation. Its instance members are abstract,
  synchronous functions returning `Unit`, with framework context parameters and no domain data parameters,
  state properties or default behaviour. For example, `core/route/RouteRegistry.register(Routing)` may
  name Ktor's routing context. Only those signature types gain a platform-import exception; other
  imports in the file and other declarations in `core` keep their restrictions. Explicit `api`, `model`,
  `usecase` packages and platform-free API/contract units do not gain this exception.
- A cache over storage: `arch-domain.md`, Repository.
- Dependency direction: the tables of `arch-context.md`. A use case and a domain contract import no platform or
  framework type; a framework registration interface has only the signature exception above. A state holder's
  interface may import its UI framework (Decompose's `ComponentContext`, `Value`), nothing else of the platform.
- No pass-through and no use case calling another: `arch-domain.md`, Use case.

### Files

- A file holds one type family: a sealed hierarchy with its variants, or a data class with the data classes
  nested in it. A class with behaviour always has its own file, even a private helper of one class
  (`RefreshingCache` is not inside `CacheRefreshingRatingRepository.kt`). A class with behaviour is any class
  or object with a function body of its own (not a data class's generated members, not an enum's entries); a
  design-system component's public `<Component>Defaults` object is the one that sits in its component's file
  (`compose.kt.md`). These mandatory file boundaries apply regardless of length. Further splitting of an
  otherwise correctly organised file is allowed only above 400 lines and must preserve those boundaries:
  a sealed family and required nested types stay together. Passing 400 lines does not itself require a split.
- A data class created as the property type of exactly one class is nested in it. A type created for two or more
  classes, or returned to another class, is top-level in `model`.
- Every error family is its own file in `model`, a sealed error with all its subclasses or a single error class
  (in Rust always one `enum`, of one variant when the family has one failure, `error-handling.rs.md`): an error
  a contract names in the `model` of the contract's level, any other in the `model` of the level that uses it,
  even one used by one class. There is no `exception` package.
- Extension functions live in `util/<Subject>Ext.kt` of the level that uses them (`KPlayerExt.kt`), even when
  one file uses them, never in the type's own file. A file that declares a class holds no top-level function; a Compose composable file
  declares no class, so an extension of a type the project does not declare that only it uses is `private` in
  it (`compose.kt.md`). A function is never an `object` used as a namespace (a `theme` object holds values,
  not functions; Compose's two exceptions: the design-system theme object's `@Composable get()` of a
  `CompositionLocal`, Material's `MaterialTheme.colorScheme`, and a design-system component's public
  `<Component>Defaults`), and there is no `Helper`, `Util` or `Manager` class.
- Wire types without a `<context>/contract` unit: a route's types live with the route and a client's in its
  technology package.

### Existing code

- **Re-layout needs approval.** Merging, moving, renaming or deleting anything that exists (a unit, a package, a
  file, a class name, DI wiring) happens only after the user approved a printed tree "before → after". A request
  such as "fix the issues" is not that approval. Without it the rules apply to new files only. A declaration's
  place is decided when it is created; a later consumer uses it where it is when the dependency tables of
  `arch-context.md` allow that edge; when they do not, the final message lists the move and the task stops short
  of that consumer. Three changes are approved in advance, each printed in the task's planned tree: an app use
  case's or state holder's interface that another unit calls moves to the owner's `api` unit (its class becomes
  `Default…`, one DI line changes); an in-memory double that production code starts to construct moves from the
  test tree to production code; a double that other units' tests need moves to `testFixtures` (KMP: the
  `<feature>/fake` unit; Rust: `arch-package.rs.md`, Tests). Everything else waits for an approved tree.
- **Re-layout does not change mechanisms.** A move changes packages, imports and the DI lines the move forces,
  nothing else. The project's mechanisms stay as they are: its `Lifecycle` objects, how listeners start
  (`val job = flowEvent(...)`), its krates, its DI wiring. The DI rule applies to the DI modules a task creates;
  existing wiring that breaks it (a flat `RootModule`) stays. Replacing a mechanism is a separate task the user
  asks for.
- Edit an old file only where the new code plugs in: a new call, a new branch, a new constructor argument, a
  new line of wiring, a new variant or property of an old type.
- New files follow this rule next to old packages named otherwise, except that the project's own word for a
  kind wins (Concepts and kinds 5). A new error goes to `model/`, not to an old `exception/`.
- The final message lists the old files the rule would move, and where.

### Enforcement

Run the project's configured linter: it checks the package names, the concept/kind shape, the naming of
implementations and the dependencies between units. The platform and framework imports of `model`, `api` and
`usecase` are those of the linter's built-in framework list and the project's technology words (Kotlin
`technologyWords`; Rust `platform-words` and `technology-words`). Answer the skill's checklist for what no check
covers.
