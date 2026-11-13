---
name: package-layout
description: Plan and review where new source files, packages and build units go in Kotlin and Rust projects: use it before the first new file of any task (feature, bugfix, refactor, test), whenever a task may need a new package, Gradle module or Cargo crate, and before moving or merging anything that exists.
version: 3.3.0
---

# Package layout

The rules `arch-package.md`, `arch-domain.md` and `arch-context.md` (the first two with their `.kt.md` and
`.rs.md` companions) say what a finished tree looks like. This skill is the order of steps for getting there and
the checklist for proving it; it states no rule. Read the rules it points to.

## 1. Before the first new file

Name what the task creates, read what its row names, follow the procedure of that row. Each row adds to the
rows above it.

| The task creates | Read | Procedure |
|---|---|---|
| no new file | nothing here | none |
| files in existing kind packages | `arch-package.md`: the kind table and names | place by the kind table |
| a new package | + `arch-package.md`: Concepts and kinds (the path of a source file) | the planned tree in the final message |
| a new unit, a dependency between units, or a move of existing code | + `arch-package.md`: Units, Existing code; `arch-context.md` | the full procedure below |
| a type with rules, a repository, a use case | + `arch-domain.md` and its language companion | as the row above that matches its files |

The full procedure:

1. Record `BASE=$(git rev-parse HEAD)`. The review at the end lists the files added since it.
2. Read the project's tree and the one-sentence `README.md` of every unit you are about to touch. Note the
   project's own words for kinds (`feature`, `component`, `slot`) and its mechanisms (`Lifecycle` objects, how
   listeners start, its DI wiring). They are kept; a word on the forbidden list (`presentation`) is not used
   for new packages.
3. **List the sub-contexts the task touches**: entry mechanisms (commands, listeners, menus, routes,
   screens), integrations with external systems, storage. Place each by the test of `arch-package.md`,
   Units 2: a concept no unit names yet that brings a stored concept or a use case is a new capability with
   its own unit (`arch-package.md`, Units 3); any other code goes where its concept's code is.
4. **If the task would merge, move, rename or delete anything that exists**, print the tree "before → after"
   for those units and packages and wait for the user's approval. "Fix the issues" or "follow the rules" is
   not approval. Without approval, apply the rules to new files only and list the moves you would make in the
   final message.
5. Answer every decision test of section 2 for the task, one line each. The lines go into the final message.
   Before adding a declaration to an `api` unit, record a table: declaration → production consumer units with
   the call, implementation or signature that uses it → placement decision (`arch-package.md`, Units 6); look
   at its related contracts, models and errors too. Tests and composition-root DI are listed apart. If usage is
   incomplete or the API has consumers outside the checkout, record that: missing references never prove an
   API unnecessary.
6. Print the planned tree of new files with full paths, and the new units with their build files.
7. Only then create files. Create a kind package the moment its first file exists, never before.

## 2. Decision tests

Each test is the question and the rule that answers it.

**T1. Which unit?** (`arch-package.md`, Units)
- A class the platform constructs (a plugin's main class, an Android `Application` or `Activity`) or
  `RootModule`: the entry-point unit.
- Something of an existing sub-context, judged by what the file does: that sub-context's unit, API or
  implementation by Units 4–6.
- A config, translation or permission model, a function, a generic class or a scope used by several
  sub-contexts: `core` (Units 1); a rule of a model that two units use: `arch-domain.md`, Rules live in `util`.
- A wire type a server and its client share: the `<context>/contract` unit.
- A new capability: Units 2 and 3 (step 1.3).

**T2. Is this a use case, and where?** `arch-domain.md`, Use case says whether; `arch-package.md`, Units 4–6
says the unit and whether an interface is needed, with the consumer table of step 1.5 for an `api` unit.

**T3. Which concept and which kind?** The path and the concept: `arch-package.md`, Concepts and kinds. The
kind, asked in this order:
1. A contract → `api`; a use case's or a state holder's interface, a test fake, a preview stub and what
   implements, wraps or narrows a contract: `arch-package.md`, Contracts and implementations.
2. Data, a result, an error, an event, a config → `model`. A rule → a function in `util`
   (`arch-domain.md`, Rules live in `util`).
3. An operation of more than one step → `usecase`. Wiring → `di`.
4. Run by the platform → the word of its mechanism in the unit it serves: `command`, `event`, the UI words,
   `service`, `warmup`, `migration`, `error`. A class a listener uses: Concepts and kinds 8, in its order.
5. Generic code that units of two sub-contexts need → `core`, in the technology package of its library.
6. Functions → `util`.
7. A class no step above fits and that keeps no state between calls (state is storage: `arch-package.md`,
   Contracts and implementations, the fifth trigger) → the role kind, the last word of its class name
   (`PacketCodec` → `codec`).

**T4. Which word for a UI kind?** `arch-package.md`, Concepts and kinds 4; Compose: `compose.kt.md`.

**T5. Does this need an interface?** One of the five triggers of `arch-package.md`, Contracts and
implementations.

**T6. One file or several?** `arch-package.md`, Files.

**T7. Which DI module?** `di-manual.kt.md` (Rust: `di-manual.rs.md`); existing wiring stays
(`arch-package.md`, Existing code).

**T8. Where is it tested?** `arch-package.kt.md`, Tests (Rust: `arch-package.rs.md`, Tests).

## 3. When no kind fits

The role kind of T3.7; its word goes into the project's linter configuration in the same change
(`arch-package.md`, Concepts and kinds 3).

## 4. Worked examples

Root packages (`…`) are the base package followed by the unit path with hyphens removed and the container
dropped (`arch-package.kt.md`).

### A plugin of one context cut by mechanism, with shared storage

```
instances/bukkit         ExamplePlugin.kt, di/RootModule.kt (builds the roots, lists their lifecycles)
modules/core/api         …core.api
  settings/model/{PluginConfig, PluginPermission, PluginTranslation}.kt
  settings/migration/ConfigKeyMigration.kt
  di/CoreModule.kt
modules/core/bukkit      …core.bukkit: di/BukkitModule.kt
modules/data/dao         …data.dao (contracts, models, in-memory implementations; no DI module)
  rating/api/{RatingRepository, RatedUsersCache}.kt
  rating/memory/InMemoryRatedUsersCache.kt   production builds it
  rating/model/{NewUser, RatedUser, RatingStorageError, RatingType, UserRating}.kt
  rating/util/UserRatingExt.kt
modules/data/exposed     …data.exposed
  rating/{ExposedRatingRepository, CacheRefreshingRatingRepository}.kt
  rating/RefreshingCache.kt                  the helper only CacheRefreshingRatingRepository uses
  rating/warmup/RatingCacheWarmUp.kt         seeds the cache at start
  rating/table/UserRatingTable.kt  rating/di/RatingStorageModule.kt
  database/RatingDatabase.kt  model/DatabaseConfig.kt  di/ExposedModule.kt
modules/gui/api          …gui.api
  rating/change/usecase/{AddRatingUseCase, LowerKillerRatingUseCase}.kt
  rating/change/model/{AddRatingResult, RatingPlayer}.kt
  rating/change/util/PluginConfigExt.kt      isRatingMessageLengthAllowed(message)
  rating/list/component/{RatingListComponent, DefaultRatingListComponent}.kt
  rating/list/model/RatingSort.kt
  rating/list/di/RatingListModule.kt         takes RatedUsersCache as a parameter
  di/GuiModule.kt
modules/gui/bukkit       …gui.bukkit
  rating/list/gui/RatingListGui.kt
  slot/{NavigationSlot, RatingSlot, SortSlot}.kt  context/SlotContext.kt  model/RatingSlotKey.kt
  util/ButtonExt.kt  di/GuiBukkitModule.kt
modules/command          …command
  rating/command/{RatingCommandExecutor, RatingLiteralArgumentBuilder}.kt  rating/model/RatingCommand.kt
  error/CommandExceptionHandler.kt  model/UsageCommandException.kt  di/CommandsModule.kt
modules/event-bukkit     …eventbukkit: event/{LoginListener, KillEventListener}.kt  di/EventModule.kt
```

A capability added later, `vote` (no unit names it; it brings a stored concept and a use case):

```
modules/vote/api         …vote.api: usecase/CastVoteUseCase.kt  di/VoteModule.kt
modules/data/dao         vote/api/VoteRepository.kt  vote/model/Vote.kt
modules/data/exposed     vote/ExposedVoteRepository.kt  vote/table/VoteTable.kt
modules/command          vote/command/{VoteCommandExecutor, VoteLiteralArgumentBuilder}.kt  vote/model/VoteCommand.kt
modules/gui/bukkit       slot/VoteSlot.kt                one file: its kind sits at the unit root
```

Dependencies: `command` → `vote/api`; `gui/bukkit` → `vote/api`; `vote/api` → `data/dao`; nothing depends on
`instances/bukkit`.

Where a new file goes: the `<concept>` paths apply when the sub-concept exists or the task adds three or more
files of two or more kinds for it, and a single new file goes to the kind of the level that has it
(`arch-package.md`, Concepts and kinds). A new menu → `gui/bukkit/rating/<concept>/gui/`; its state holder →
`gui/api/rating/<concept>/component/`; a new use case of the rating concept →
`gui/api/rating/<concept>/usecase/`; a new storage query → `data/dao/rating/api/RatingRepository` plus
`data/exposed/rating/ExposedRatingRepository`; a start-up seed → `data/exposed/rating/warmup/`; a config format
change → `core/settings/migration/`; a listener → `event-bukkit/event/`.

### A plugin of several capabilities

```
modules/jail/api         …jail.api
  usecase/{JailPlayerUseCase, FreeInmateUseCase}.kt
  model/{Jail, JailInmate, JailLocation, JailError}.kt
  api/JailRepository.kt
  file/FileJailRepository.kt              technology package: implementations directly
  memory/InMemoryJailRepository.kt
  di/JailModule.kt
modules/jail/bukkit      …jail.bukkit
  command/JailCommand.kt  event/JailListener.kt  service/UnjailService.kt
  util/JailLocationExt.kt  di/JailBukkitModule.kt
modules/home             …home: nothing else calls it, so one unit
  command/HomeCommand.kt  usecase/TeleportHomeUseCase.kt  model/Home.kt  di/HomeModule.kt
```

The `jail/api` unit exists because `home` calls it; a capability only its own platform unit uses stays in one
unit. Dependencies: `jail/bukkit` → `jail/api`; `home` → `jail/api`; `jail/api` depends on no other capability.

### An app

```
core/ui                         …core.ui: theme/AppTheme.kt  composable/ButtonComposable.kt
components/shop/payment/api     …shop.payment.api
  offer/api/PaymentApi.kt  offer/model/Plan.kt  offer/stub/StubPaymentApi.kt
  offer/usecase/CheckSubscriptionUseCase.kt (interface)
  offer/component/OfferComponent.kt (interface: another unit opens the offer)
components/shop/payment/impl    …shop.payment.impl
  offer/usecase/DefaultCheckSubscriptionUseCase.kt  offer/ktor/KtorPaymentApi.kt  offer/di/PaymentModule.kt
components/shop/payment/impl-ui …shop.payment.implui
  offer/composable/OfferScreenComposable.kt  offer/component/DefaultOfferComponent.kt
  offer/di/PaymentUiModule.kt
```

Dependencies: `shop/impl` → `payment/api` (calls `CheckSubscriptionUseCase`); `payment/impl-ui` →
`payment/api`, `payment/impl` and `core/ui`; the entry-point unit depends on `payment/impl-ui` and `payment/impl`.

### A Rust workspace

`arch-package.rs.md` translates the kinds: a unit is a crate under `modules/` (an entry point under
`instances/`, tooling in `xtask`), a package is a module block of the root file, a source set is code under a
target `cfg`, shared test fakes are the `fixture/` tree of the crate that owns the trait behind its `fake`
feature, and procedural macros are a `proc-macro` crate.

```
modules/billing/api       shop-billing-api: src/invoice/{api,model,usecase,util,file,di}/…, test/invoice/…,
                          fixture/invoice/fake/fake_invoice_repository.rs ([features] fake = [])
modules/billing/command   shop-billing-command: [dev-dependencies] shop-billing-api with features = ["fake"]
instances/cli             shop-cli: src/lib.rs (the module tree: di/root_module.rs, RootModule),
                          src/main.rs (`use` lines, the runtime, `fn main`)
xtask                     cargo xtask <task>
```

Dependencies: `shop-billing-command` → `shop-billing-api`; `shop-cli` → both; nothing depends on `shop-cli`.

## 5. Before the final message

List the files the task added (`git diff --name-only --diff-filter=A $BASE`; without `BASE`,
`git status --short`) and answer each item in one line. A "no" is fixed by moving the new file; an old file
moves only for the three changes of Existing code.

1. Is the project's configured linter green?
2. Did the task merge, move, rename or delete nothing without the user's approval of a "before → after" tree,
   except the three changes of Existing code, printed in its planned tree? (No check sees an approval.)
3. Did a move change only packages, imports and DI lines, leaving `Lifecycle`, listener start-up and krates as
   they were? (No check compares a move with the old tree.)
4. Was every new capability placed by the test of `arch-package.md`, Units 2? (No check knows what a
   capability is.)
5. Is every use case in the unit Units 4–6 name, and does the consumer table justify each addition to an
   `api` unit? (The ownership report is advisory and covers consumers only.)
6. Are UI kinds named from the framework and the project, `viewmodel` only for a view model, the project's own
   word kept? (No check reads the project's words.)
7. Is every implementation named by its technology, its variant or `Default<Interface>`? (The checks read
   `Impl`, `I` and `Interface` only.)
8. Does every new interface pass one of the five triggers? (No check knows why an interface exists.)
9. Is every model and every function in the `model` or `util` of the level that uses it? (No check reads
   which level uses a declaration.)
10. Does every cache sit in storage, every start-up seed in the unit of the state it seeds, every failure
    handler in `error` of its mechanism? (The checks place a `…WarmUp` by package, not by unit, and read
    neither caches nor handlers.)
11. Does every new unit that assembles dependencies have its own DI module, and did the existing DI wiring stay
    as it was? (No check reads a missing DI module or an unchanged wiring.)
12. Is each in-memory implementation placed by who constructs it: production code, the test tree, or
    `testFixtures`? (`InMemoryPlacement` reads the `memory` package, not who constructs the class.)
13. Does the final message list the old files the rules would move, and where? (No check reads a message.)
