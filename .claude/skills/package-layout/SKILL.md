---
name: package-layout
description: Plan and review where new source files, packages and build units go in Kotlin and Rust projects. Use before creating the first new file of any task (feature, bugfix, refactor, test), whenever a task may need a new package, Gradle module or Cargo crate, and before moving or merging anything that exists. Gives the planning procedure, the questions to ask the user, the decision tests, worked examples and the review checklist.
version: 3.1.0
---

# Package layout

The rules `arch-package.md`, `arch-domain.md` and `arch-context.md` (the first two with their `.kt.md` and
`.rs.md` companions) say what a finished tree looks like. This skill is the procedure for getting there and the
checklist for proving it. Read the rules first; this file does not repeat them.

## 1. Before the first new file

1. Record `BASE=$(git rev-parse HEAD)`. The review at the end lists the files added since it.
2. Read the project's tree and the one-sentence `README.md` of every unit you are about to touch. Note the
   project's own words for kinds (`feature`, `component`, `slot`) and its mechanisms (`Lifecycle` objects, how
   listeners start, its DI wiring). They are kept; a word on the forbidden list (`presentation`) is not used
   for new packages.
3. **List the sub-contexts the task touches**: entry mechanisms (commands, listeners, menus, routes,
   screens), integrations with external systems, storage. For each one that has no unit yet, ask the user:
   "own unit (`modules/<name>`), or a package in `<existing unit>`?" Show both trees. Without an answer the
   code goes as a package into the existing unit.
4. **If the task would merge, move, rename or delete anything that exists**, print the tree "before → after"
   for those units and packages and wait for the user's approval. "Fix the issues" or "follow the rules" is
   not approval. Without approval, apply the rules to new files only and list the moves you would make in the
   final message.
5. Answer every decision test of section 2 for the feature, one line each. The lines go into the final message.
6. Print the planned tree of new files with full paths, and the new units with their build files.
7. Only then create files. Create a kind package the moment its first file exists, never before.

## 2. Decision tests

**T1. Which unit?**
- A class the platform constructs (a plugin's main class, an Android `Application` or `Activity`) or
  `RootModule`: the entry-point unit.
- Something of an existing sub-context, judged by what the file does (warming the rating cache is storage,
  even though the platform starts it): that sub-context's unit; code other units call, and every plugin use
  case, in its `api` unit when the sub-context is split (a use case of an unsplit one stays in its one unit,
  and another sub-context needing it is a reason to propose the split, `arch-package.md` Units 2); code only
  the platform unit uses, platform-free or not, in the platform unit (`RatingSlotKey`).
- A config, translation or permission model, a function, a generic class or a scope used by several
  sub-contexts: `core`, in the concept → kind shape. A rule of a model that two units use is the exception:
  the `util` of the model's own unit.
- A wire type a server and its client share: the `<context>/contract` unit.
- A new sub-context: ask (step 1.3).

**T2. Is this a use case, and where?**
Only when the flow has more than one step: a contract call whose result
a model rule judges before acting, or two or more contracts combined. Named `<Verb><Object>UseCase`, in the
`usecase` package of its concept, in the `api` unit of the sub-context that owns the operation, or in its one
unit when it is not split. In an app, a use case lives in `usecase` of the `impl` unit; when another unit
calls it, its interface sits in `usecase` of the owner's `api` unit and the `Default…` implementation stays in
`impl`. Never in `core`. If the owner is unclear, ask.

**T3. Which concept and which kind?**
Path: `<unit root>[/<concept>[/<sub-concept>]]/<kind>[/<sub-kind>]/<File>`, the sub-kind for Compose's `composable` only
(T4). The concept is the thing in the project's words (`rating`). The
kind, asked in this order:
1. Contract → `api`; a use case's or a state holder's interface → `usecase` or the state-holder kind, with its
   implementation; in an app, when another unit calls it, the interface in that kind of the owner's `api`
   unit. A Kotlin test fake → `fake`, following the test-sharing layout in `arch-package.kt.md`; a preview
   stub → `stub`. Implements, wraps or narrows a contract (a cache included) → beside the other
   implementations, in storage when it caches storage.
2. Data class, result, error, event, config → `model`, as data (`arch-domain.md`: fields, nested types,
   constants, an invariant check). A rule over a type → an extension of that type in `util`
   (`arch-domain.md`).
3. Operation of more than one step → `usecase`. Wiring → `di`.
4. Run by the platform → the word of its mechanism, in the unit it serves: `command`, `event`, the UI words,
   `service` (timer), `warmup` (once at start), `migration` (format change), `error` (failure to reply).
5. Generic code that units of two sub-contexts need → `core`, in the technology package of the library it is
   built on (`core/cache/cache4k`); until then beside its only user.
6. Functions (extensions, rules of the model, formatting) → `util`. Never a class.
Nothing lies loose in a concept package outside a unit that is wholly one technology.

**T4. Which word for a UI kind?**
Compose: `composable`, `theme` (shared values of a level) and the state holder's word (`viewmodel` or a
Decompose `component`); UI types in the level's `model`, shared Compose extensions in its `util`, a one-file
one `private` in the composable file, no `composable/model` or `composable/util`; `composable` alone may split
into `screen`, `component`, `layout` and the project's own words, files or sub-packages but never both
(`compose.kt.md`). Anything else: derive from the framework's classes and the project's words.
AstraLibs menus: the project's words (AstraRating: `gui`, `slot`, `context`, `component`, `model`). A router is a
contract in `api` with its implementation beside the other implementations, not a UI kind.
The project's existing word wins unless it is forbidden.

**T5. Does this need an interface?**
Exactly four triggers: another unit calls it; two or more implementations exist or one is known to come; an
inner part declares what it needs from an outer one; a test must replace a contract over I/O or the platform.

**T6. One file or several?**
A sealed type with its variants, or a data class with its nested data classes, is
one file. Every class with behaviour and every error family has its own file, regardless of length. The
400-line threshold permits only further splitting that preserves these boundaries. Extensions go to
`util/<Subject>Ext.kt`, except an extension of a type the project does not declare that only a Compose
composable file uses, which is `private` there. There is no `Helper`, `Util` or `Manager` class.

**T7. Which DI module?**
The unit's own DI module in `di` of the level it wires, with its own `lifecycle` when it starts or stops
something; a database or other resource with its own lifecycle gets its own DI module. The module that
directly constructs a child manages that child's lifecycle; a module received as a dependency is never
started, reloaded or stopped by the receiver. `RootModule` follows the same rule. Dependency references
may be shared without sharing lifecycle ownership. A `warmup` or `migration` is built and started by the DI
module of the resource it prepares. A DI module that cannot reach the providing module takes the contract as a
parameter. Never merge DI modules, never replace `Lifecycle` with functions, and leave existing wiring as it
is, even where it breaks the DI rule.

**T8. Where is it tested?**
A model rule directly; a use case with fakes or an in-memory implementation; a technology implementation
against the real technology in a test; the wired plugin in the entry-point unit. Shared KMP fakes are public
in `<feature>/fake`'s `commonMain`, under `<concept>/fake`, and consumed only by test source sets. JVM shared
fakes use `testFixtures`; ordinary same-unit fakes stay in the test tree.

## 3. When no kind fits

Stop and ask the user. Name the file, what it does, why no kind of T3 fits, and the word a new kind would
have. `util` and `model` are never the fallback for a class. A task does not extend the menu on its own.

## 4. Worked examples

### A plugin with one context cut into sub-contexts (AstraRating)

The tree as it stands, real class names, root packages without `ru.astrainteractive.astrarating`. Some parts
predate the rules and stay until the owner asks to move them (`players` in the plural, the state `Model`
nested in `RatingPlayersComponent`, `KotlinDispatchers` passed to `RatingPlayersModule` instead of the module
that provides it); new files follow the rules:

```
instances/bukkit         AstraRating.kt, di/RootModule.kt (builds roots, lists their lifecycles)
modules/core/api         …core
  settings/model/{AstraRatingConfig, AstraRatingPermission, AstraRatingTranslation}.kt
  settings/migration/ConfigSnakeCaseMigration.kt
  di/CoreModule.kt
modules/core/bukkit      …core: di/BukkitModule.kt
modules/data/dao         …data.dao (contracts, models, in-memory doubles; no DI module)
  rating/api/{RatingRepository, RatingCache, RatedUsersCache}.kt
  rating/memory/InMemoryRatingCache.kt
  rating/model/{NewUser, RatedUser, RatingStorageError, RatingType, User, UserRating}.kt
  rating/util/RatingRepositoryExt.kt
modules/data/exposed     …data.exposed
  rating/{ExposedRatingRepository, CacheRefreshingRatingRepository, Cache4kRatingCache, Cache4kRatedUsersCache}.kt
  rating/RefreshingCache.kt                 the helper only CacheRefreshingRatingRepository uses, beside it
  rating/warmup/RatingCacheWarmUp.kt       seeds RatingCache at start through PlatformServer
  rating/di/RatingStorageModule.kt         builds the caches, starts the warm-up in its lifecycle
  table/{UserTable, UserRatingTable}.kt  model/DbRatingConfiguration.kt  di/ExposedModule.kt
modules/gui/api          …gui.api
  rating/change/usecase/AddRatingUseCase.kt
  rating/change/model/{AddRatingResult, RatingPlayer}.kt
  rating/change/util/AstraRatingConfigExt.kt   isRatingMessageLengthAllowed(message)
  rating/players/component/{RatingPlayersComponent, DefaultRatingPlayersComponent}.kt
  rating/players/model/UsersRatingsSort.kt
  rating/players/di/RatingPlayersModule.kt     takes RatedUsersCache and KotlinDispatchers as parameters
  rating/player/{component, model, util, di}/…   router/api/GuiRouter.kt  util/{IterableExt, ListExt}.kt  di/GuiModule.kt
modules/gui/bukkit       …gui.bukkit
  rating/players/gui/RatingsGUI.kt  rating/player/gui/PlayerRatingsGUI.kt
  slot/{EventSlot, NavigationSlots, RatingsSlot, PlayerRatingsSlot, SortSlot, GuiLoadingIndicator, ConnectionLines}.kt
  context/SlotContext.kt  model/RatingSlotKey.kt  router/BukkitGuiRouter.kt
  util/{ButtonExt, DateFormat, MessageLines, OfflinePlayerExt, UserExt, RatingInventoryLayout, …}.kt
  di/GuiBukkitModule.kt
modules/command          …command
  rating/command/{RatingCommandExecutor, RatingLiteralArgumentBuilder}.kt  rating/model/RatingCommand.kt
  rating/util/KPlayerExt.kt  reload/command/ReloadLiteralArgumentBuilder.kt
  error/CommandExceptionHandler.kt  model/UsageCommandException.kt  di/CommandsModule.kt
modules/event-bukkit     …event: login/event/LoginEvent.kt (val job; an old name, new ones are …Listener),
                         kill/event/KillEventListener.kt, di/EventModule.kt
modules/integration-papi …integration.papi
  placeholder/expansion/{RatingPlaceholderExpansion, RatingAmountPlaceholder, ColorPlaceholder}.kt
  placeholder/api/RatingPlaceholder.kt  placeholder/model/{PapiConfig, Coloring}.kt  di/PapiModule.kt
```

Where a new file goes: a new menu → `gui/bukkit/rating/<concept>/gui/`; its state holder →
`gui/api/rating/<concept>/component/`; an operation two units call → `gui/api/rating/<concept>/usecase/`; a new
storage query → `data/dao/rating/api/RatingRepository` plus `data/exposed/rating/ExposedRatingRepository`; a start-up
seed → `data/exposed/rating/warmup/`; a config format change → `core/settings/migration/`; a new placeholder →
`integration-papi/placeholder/expansion/`.

### A plugin with several contexts (AspeKt, a new `jail` context)

```
modules/jail/api                   …module.jail.api
  jail/usecase/{JailPlayerUseCase, FreeInmateUseCase}.kt
  jail/model/{Jail, JailInmate, JailLocation, JailError}.kt
  jail/api/JailRepository.kt
  jail/file/{FileJailRepository}.kt       technology package: implementations directly
  jail/memory/{InMemoryJailRepository}.kt
  jail/di/JailModule.kt
modules/jail/bukkit                …module.jail.bukkit
  jail/command/JailCommand.kt  jail/event/JailListener.kt  jail/service/UnJailServiceTask.kt
  jail/util/LocationExt.kt  jail/di/JailBukkitModule.kt
```

### An app feature (`payment`)

```
components/shop/payment/api    …payment.api: offer/api/PaymentApi.kt, offer/model/Plan.kt,
                               offer/usecase/CheckSubscriptionUseCase.kt (interface), offer/stub/StubPaymentApi.kt,
                               offer/component/OfferComponent.kt (interface, another unit opens the offer)
components/shop/payment/impl   …payment.impl: offer/usecase/DefaultCheckSubscriptionUseCase.kt,
                               offer/composable/…, offer/component/DefaultOfferComponent.kt,
                               offer/revenuecat/RevenueCatPaymentApi.kt,
                               offer/di/PaymentModule.kt; androidMain at the same paths
```

### A Rust crate

Rust follows `arch-package.rs.md` and `arch-domain.rs.md`: a context block holds its use cases and kind
blocks. Of this skill, the procedure of section 1, T5, T6, T8 and the checklist items that do not name
Kotlin or Gradle apply; T1–T4 and T7 do not.

## 5. Before the final message

List the files added since `BASE` (`git diff --name-only --diff-filter=A $BASE`) and answer each item in one
line. A "no" is fixed by moving the new file, never an old one.

1. Did the task merge, move, rename or delete nothing without the user's approval of a "before → after" tree?
2. Did a move change only packages, imports and DI lines, leaving `Lifecycle`, listener start-up and krates as
   they were?
3. Was every new sub-context offered to the user as "own unit or package", and does every new unit have a
   one-sentence `README.md`?
4. Is every use case named `…UseCase`, in a `usecase` package, in the `api` unit that owns the operation or
   the one unit of an unsplit owner (in an app, in `impl`, with its interface in the owner's `api` unit when
   another unit calls it), and never in `core`? Does `core` depend on no feature unit?
5. Does any package hold both files and packages, other than the concept package of a unit that is wholly one
   technology and the root of the entry-point unit? Does every concept package hold only kind packages, except
   in a unit that is wholly one technology? Does every kind package hold only files, except a Compose
   `composable` split into `screen`/`component`/`layout` or the project's own words?
6. Are UI kinds named from the framework and the project, with `composable`/`theme` only under Compose,
   `viewmodel` only for a view model, and the project's own word kept?
7. Does any package created inside a unit carry a forbidden name (`domain`, `impl`, `internal`, `repository`,
   `exception`, `dto`, `dao`, `common`, `presentation`, `port`, `adapter`, …)? Are all package names
   singular (the reviewer's call)?
8. Does every contract sit in `api` of its concept (a use case's interface in `usecase`, a state holder's in
   its state-holder kind; in an app, one another unit calls in that kind of the owner's `api` unit), with its
   implementation named by technology, variant or `Default<Interface>`, no `Impl`, no `I` prefix?
9. Does every new interface pass one of the four triggers?
10. Is every model and every function in the `model` or `util` of the level that uses it, or, for a rule two
    units use, in the `util` of the model's own unit?
11. Does every class with behaviour and every error type have its own file, and every extension sit in
    `util/<Subject>Ext.kt` (or, for a type the project does not declare, `private` in the one Compose
    composable file that uses it)? Does any `util` hold a class or an `object` declaration (an anonymous
    `object :` of a bridge is allowed)? Does any top-level function take a type as a parameter where an
    extension of that type is the rule?
12. Does every cache sit in storage, every start-up seed in `warmup` of the unit it seeds, every failure
    handler in `error` of its mechanism, every format converter in `migration` of what it converts?
13. Does `model` import no kind but other `model` packages, and no platform or ORM type (Compose types only in
    a UI unit's `model`, a framework's exception subclasses only in the unit of that framework's entry point)?
    Do `api` and `usecase` import no platform type? Does a plugin's `api` unit declare no platform dependency?
14. Do production dependencies follow the table in `arch-context.md` without cycles, with the Kotlin
    test-sharing exceptions confined to test dependencies and each compilation's graph acyclic?
15. Does every new unit that assembles dependencies have its own DI module, with its own `lifecycle` when it
    starts or stops something? Does it manage only DI modules it directly creates, never injected modules,
    and did the existing DI wiring stay as it was?
16. Are tests mirrored package for package, fakes in `fake/`, in-memory implementations in `memory`? Are
    shared Kotlin fakes exported through `testFixtures` or a KMP fake unit's `commonMain`, consumed only by tests?
17. Does the final message list the old files the rules would move, and where?

The checker that runs items 5, 7, 8, 11 (a class in `util`) and 14 mechanically is not written yet; until it exists,
answer them by hand and say so in the final message.
