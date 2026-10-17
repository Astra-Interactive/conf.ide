---
name: package-layout
description: Plan and review where new source files, packages and build units go in Kotlin and Rust projects. Use before creating the first new file of any task (feature, bugfix, refactor, test), whenever a task may need a new package, Gradle module or Cargo crate, and before moving or merging anything that exists. Gives the planning procedure, the questions to ask the user, the decision tests, worked examples and the review checklist.
version: 3.0.0
---

# Package layout

The rules `arch-package.md`, `arch-domain.md` and `arch-context.md` (with their `.kt.md` and `.rs.md`
companions) say what a finished tree looks like. This skill is the procedure for getting there and the
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
- The platform main class or `RootModule`: the entry-point unit.
- Something of an existing sub-context, judged by what the file does (warming the rating cache is storage,
  even though the platform starts it): that sub-context's unit; platform-free code in its `api` unit,
  platform code in its platform unit.
- A config, translation or permission model, a helper, a scope used by several sub-contexts: `core`.
- A wire type a server and its client share: the `<context>/contract` unit.
- A new sub-context: ask (step 1.3).

**T2. Is this a use case, and where?**
Only when the flow has more than one step: a contract call whose result a model rule judges before acting, or
two or more contracts combined. Named `<Verb><Object>UseCase`, in the `usecase` package of its concept, in the
`api` unit of the sub-context that owns the operation. Never in `core`. If the owner is unclear, ask.

**T3. Which concept and which kind?**
Path: `<unit root>/<concept>/<kind>/<File>`. The concept is the thing in the project's words (`rating`). The
kind: contract → `api`; data class, result, error, event, config → `model`; operation → `usecase`; extension
or helper → `util`; wiring → `di`; entry point → the project's or the framework's word for its mechanism;
implementation → the technology package or unit (`exposed`, `memory`), where the concept package holds the
implementations directly. Nothing lies loose in a concept package outside a technology implementation.

**T4. Which word for a UI kind?**
Compose: `composable`, `viewmodel`. Anything else: derive from the framework's classes and the project's words.
AstraLibs menus: `menu`, `component`, `context`, `feature`, `model`. The project's existing word wins unless it
is forbidden.

**T5. Does this need an interface?**
Exactly four triggers: another unit calls it; two or more implementations exist or one is known to come; an
inner part declares what it needs from an outer one; a test must replace a contract over I/O or the platform.

**T6. One file or several?**
A sealed type with its variants, or a data class with its nested data classes, is one file. Every class with
behaviour, every error type and every helper class has its own file. Extensions go to `util/<Subject>Ext.kt`.

**T7. Which DI module?**
The unit's own DI module in `di` of the level it wires, with its own `lifecycle`; a database or other resource
with its own lifecycle gets its own DI module. Add the new module as a child of the module that owns its
dependencies, or list it in `RootModule`. Never merge DI modules, never replace `Lifecycle` with functions,
and leave existing wiring as it is, even where it breaks the DI rule.

**T8. Where is it tested?**
A model rule directly; a use case with fakes or an in-memory implementation; a technology implementation
against the real technology in a test; the wired plugin in the entry-point unit.

## 3. When no kind fits

Put the file into the closest kind of the menu and report in the final message which file, which kind was
chosen and why none fits, with the word a new kind would have. A task does not extend the menu.

## 4. Worked examples

### A plugin with one context cut into sub-contexts (AstraRating)

```
instances/bukkit                   AstraRating.kt, di/RootModule.kt (builds roots, lists their lifecycles)
modules/core/api                   …core: settings/model/{AstraRatingConfig, AstraRatingTranslation, AstraRatingPermission}.kt,
                                   coroutine/…, di/CoreModule.kt
modules/core/bukkit                platform pieces of core
modules/data/dao                   …data.dao
  rating/api/RatingRepository.kt
  rating/model/{Rating, User, UserRating}.kt
modules/data/exposed               …data.exposed
  rating/{ExposedRatingRepository, CachedRatingRepository, RefreshingCache, RatingCacheWarmUp}.kt
  table/{UserTable, UserRatingTable}.kt
  database/RatingDatabase.kt
  model/DbRatingConfiguration.kt
  di/ExposedModule.kt              databaseFlow and its lifecycle
modules/gui/api                    …gui.api: platform-free, others may call it
  rating/usecase/{RatePlayerUseCase, LowerKillerRatingUseCase}.kt
  rating/model/…  rating/api/…  rating/di/RatingGuiModule.kt
modules/gui/bukkit                 …gui.bukkit
  menu/{RatingsMenu, PlayerRatingsMenu, MenuRouter}.kt
  component/{NavigationSlots, SortSlot, EventSlot, RatingsSlot, GuiLoadingIndicator}.kt
  context/SlotContext.kt
  feature/{RatingsFeature, PlayerRatingsFeature}.kt
  model/RatingSlotKey.kt
  util/PlayerHeadExt.kt
  di/GuiBukkitModule.kt
modules/command                    …command: rating/command/RatingCommand.kt, rating/model/UsageCommandException.kt,
                                   rating/util/KPlayerExt.kt, di/CommandModule.kt
modules/event-bukkit               …event: login/event/LoginEvent.kt (val job, as the project starts listeners)
modules/integration-papi           …integration.papi: placeholder/…/RatingPlaceholderExpansion.kt,
                                   placeholder/model/PapiConfig.kt, di/PapiModule.kt
```

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
  jail/command/JailCommand.kt  jail/event/JailEvent.kt  jail/service/UnJailServiceTask.kt
  jail/util/LocationExt.kt  jail/di/JailBukkitModule.kt
```

### An app feature (BUSY, `monetization`)

```
components/bsb/monetization/api    …monetization.api: offer/api/MonetizationApi.kt, offer/model/Plan.kt,
                                   offer/stub/StubMonetizationApi.kt
components/bsb/monetization/impl   …monetization.impl: offer/usecase/CheckEntitlementUseCase.kt,
                                   offer/composable/…, offer/viewmodel/…, offer/revenuecat/RevenueCatEntitlementRepository.kt,
                                   offer/di/MonetizationModule.kt; androidMain at the same paths
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
4. Is every use case named `…UseCase`, in a `usecase` package, in the `api` unit that owns the operation, and
   never in `core`? Does `core` depend on no feature unit?
5. Does every concept package hold only kind packages, except a technology implementation?
6. Are UI kinds named from the framework and the project, with `composable`/`viewmodel` only under Compose and
   the project's own word kept?
7. Does any package created inside a unit carry a forbidden name (`domain`, `impl`, `internal`, `repository`,
   `exception`, `dto`, `dao`, `common`, `presentation`, `port`, `adapter`, …)? Are all package names
   singular?
8. Does every contract sit in `api` of its concept, with its implementation named by technology or variant, no
   `Impl`, no `I` prefix?
9. Does every new interface pass one of the four triggers?
10. Is every model and every helper in the `model` or `util` of the level that uses it?
11. Does every class with behaviour, every error type and every helper class have its own file, and every
    extension sit in `util/<Subject>Ext.kt`?
12. Does `model` import nothing of its level and no platform or ORM type? Do `api` and `usecase` import no
    platform type? Does a plugin's `api` unit declare no platform dependency?
13. Does every dependency between units follow the table in `arch-context.md`, with no cycle?
14. Does every new unit that constructs something have its own DI module with its own `lifecycle`, in a
    tree, and did the existing DI wiring stay as it was?
15. Are tests mirrored package for package, fakes in `fake/`, in-memory implementations in `memory`?
16. Does the final message list the old files the rules would move, and where?

The checker that runs items 5, 7, 8, 12 and 13 mechanically is defined in the checker stage; until it exists,
answer them by hand and say so in the final message.
