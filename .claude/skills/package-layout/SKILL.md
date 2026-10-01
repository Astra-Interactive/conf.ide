---
name: package-layout
description: Plan and review where new source files, packages and build units go in Kotlin and Rust projects. Use before creating the first new file of any task (feature, bugfix, refactor, test) and whenever a task may need a new package, Gradle module or Cargo crate. Gives the planning procedure, the build-unit criteria, sub-concept and layer thresholds, the new-kind procedure, worked examples and the review checklist.
version: 1.0.0
---

# Package layout

The always-on package-layout rule and its Kotlin and Rust companions say what a finished tree looks like. This
skill gets a task there in three steps: plan the tree before the first file, write the files at the planned
paths, review the tree after the last file.

## 1. Plan: before the first file

1. **Base.** Record the commit the task starts from: `BASE=$(git rev-parse --verify -q HEAD || echo "")`.
2. **Scope.** List the task's domain nouns, its entry points (commands, screens, menus, listeners) and the
   external systems it touches (database, HTTP, Discord, Vault, files).
3. **Build units** (§4.1). For each group of new files write one line: the unit, and the rule that picked it
   (owner unit, B1, B2, B3, or "the unit that holds the concept").
4. **Concepts** (§4.2, §4.3). Attach every file to a contract group; decide the sub-concepts and screens; name
   them.
5. **Kinds** (the table in the always-on rule). Give every file its kind row. Pass every interface, conversion,
   use case and DI module through the gates (§4.5). A role no row names goes through §4.6.
6. **Layers** (§4.4). Count the concept's child packages and files; apply the trigger.
7. **Visibility.** Give every file's top-level declarations their modifier from the visibility rule.
8. **Print the plan** in the reply, in this shape, before creating any file:

```
Layout plan (BASE 3f2a9c1)
Units
  new    :modules:clan              B1: own commands and listeners; no existing unit imports it
  owner  none                       the project's feature units own their databases
Concept clan (unit root): L2 — 10 children, 25 files, use cases, a database; sub-concepts: none
Files
  domain/api/ClanRepository.kt      api        internal   A1: faked in the use-case tests
  domain/model/Clan.kt              model      internal   nests Member and its Rank
  data/database/ExposedClanRepository.kt   database   internal   row → Clan: private extension here (A2)
  di/ClanModule.kt                  di         public     instances/bukkit RootModule constructs it
  …
Tree
  (ascii tree of every new and touched package)
Old code: nothing moved; edited in place: instances/bukkit/…/di/RootModule.kt, settings.gradle.kts
```

## 2. Write

Create the files at the planned paths. A file the plan does not have goes through steps 4–7 first, and the
printed tree is updated in the reply.

## 3. Review: after the last file

List what the task added and whether an old file moved:

```sh
{ [ -n "$BASE" ] && git diff --name-only --diff-filter=A "$BASE"; git ls-files --others --exclude-standard; } | sort -u
[ -n "$BASE" ] && git diff --name-status "$BASE" | grep -E '^[RD]'
```

Answer each item in one line with its evidence, from the listing and the plan:

1. **Loose files.** Every new source file lies in a kind package, or is the entry point, or lies in an `api`-unit
   root or an owner-unit concept (the three exceptions of the Shape rule).
2. **Mixed packages.** No package the task created holds both files and packages.
3. **Names.** Every new package is lowercase, singular, one segment, a kind row or a reported new kind or a concept
   noun; a role the unit already names with another word (`impl/`, `commands/`) uses that word, in new
   sub-concepts too.
4. **Families.** Every sealed type and enum the task created is one file with all its variants; every new data
   class that is a property type of exactly one class is nested in it; every result a function returns to
   another class is its own file in `model/`; no new file passes 400 lines.
5. **Visibility.** Every new top-level declaration has the visibility the rule gives; public (no modifier in
   Kotlin, `pub` in Rust) only on the entry point and on what another unit uses; no Kotlin file contains the
   keyword `public`.
6. **Units.** Every new unit has its written criterion, is registered in the build, depends only in the
   allowed direction (impl → api, platform → api/impl, feature → owner unit), is wired into the composition
   root, and, for a Rust crate, has `unreachable_pub` switched on (a Kotlin unit never enables `explicitApi()`).
   No unit's directory holds another unit. In a refactor the user asked for, every old unit passes the same
   check and has the shape of §4.1.
7. **Gates.** Every new interface, `mapping/` file, use case and DI module passes §4.5.
8. **Tests.** Every new test mirrors the package of the class it tests; fakes sit in `fake/` inside the concept of
   the contract they replace; fakes other units use sit in `testFixtures`, in a `<feature>/fake` sibling unit
   (Kotlin Multiplatform) or in a `<name>-test-support` crate (Rust).
9. **Old code.** The second command printed nothing: no pre-existing file was moved, renamed or deleted. In
   `git diff "$BASE" -- <old files>` every changed line is an integration point (a call, a branch, a
   constructor argument, wiring); a rename, a moved helper, a reformatted or restyled old line is reverted.

Rust adds: only `src/lib.rs` declares modules (old `mod.rs` modules excepted); `src/` holds only `lib.rs` and
`main.rs`; no file under `src/` contains `#[cfg(test)]`, `#[test]` or `mod tests`.

A "no" is fixed by moving or rewriting the new file, never an old one. The final message then carries a
**Layout** section:

```
Layout
- New units: :modules:clan (B1).
- New kinds: policy — rules a clan action must pass, 3 files.
- Old files the rules would move: none.
- Kind packages over 20 files: none.
```

When the user asks for the automated check, run `bash <this skill's directory>/check-layout.sh "$BASE"` from the
repository root and answer its findings the same way. Do not run it unasked.

## 4. Reference

### 4.1 Build units

**Owner units come first.** An owner unit is an existing unit named after a kind or a technology (`data`, `dao`,
`exposed`, `database`, `command`, `gui`, `event`, `network`) that holds that kind for other features.

- A new feature's files of that kind go to the owner unit, under a concept package named after the feature.
  Where owner units split contract and implementation (`data/dao` holds DAO interfaces, `data/exposed` their
  Exposed implementations), follow the split.
- Inside an owner unit, the feature's concept package is a leaf when every file in it has the unit's kind
  (`modules/command/…/nickname/NickCommand.kt`), and a branch of kinds otherwise (`modules/data/…/nickname/{api,
  model, database}`).
- The feature unit depends on the owner units; an owner unit never depends on a feature unit.

**A new unit is created when one of these holds:**

- **B1 feature of its own.** The project has more than one build unit besides its entry-point units, and the
  new code has entry points of its own (commands, screens, menus, listeners) or state of its own (a new table,
  file or store) with operations on it. It gets a unit even when its UI is drawn inside an existing screen or
  menu: the existing unit depends on the new unit's contract and calls it, and the persistence still goes to the
  owner unit. Example: a favourites feature whose star button sits on the existing product screen is
  `feature/favourites/api` + `feature/favourites/impl`; the product screen calls `FavouritesRepository` from
  `favourites/api`. A change with no entry point and no state of its own (a new subcommand of `/link`, one more
  field an existing screen shows) joins the unit of the feature it extends.
- **B2 isolation.** One part must not see another: platform code and the platform-free logic whose tests must run
  without the server API; a heavy library (a database driver, an HTTP client) other units must not get
  transitively; or the user asks for the split.
- **B3 shared.** Two or more units need the same code: it goes to a unit both depend on, never into a copy.

The number of units the project has is not a criterion beyond B1's single-unit / multi-unit distinction. In a
single-unit project a new feature is a concept package in that unit unless B2 or B3 holds.

**Shapes:**

| Project | New feature unit |
|---|---|
| app (Android or Compose Multiplatform, features as units) | always `feature/<name>/api` + `feature/<name>/impl`. `api` holds the contracts other units call (the screen entry or route, repository contracts) and the models in their signatures; `impl` holds everything else and depends on `api`; only the composition root depends on `impl`. |
| plugin or bot, one platform | one unit `modules/<name>` (the project's container for feature units). With B3 (another unit calls or implements its contracts): `<name>/api` (contracts and the models in their signatures) + `<name>/impl` (everything else). With B2: `<name>/api` (everything that compiles without the platform: contracts, models, use cases, domain kinds, platform-free implementations) + `<name>/<platform>` (commands, listeners, menus, platform adapters, its DI module). |
| plugin, ≥ 2 platforms | `<name>/api` (contracts and models) + `<name>/impl` (the platform-free implementation the platform units share) + one unit per platform (`bukkit`, `fabric`, `velocity`) when the feature has platform code. |
| Rust workspace | one crate per independent feature, in the workspace's container (`modules/<name>`), crate name = directory name; fakes other crates need in `<name>-test-support`. |

`<name>/` itself is a container: no build file, no sources. A unit never sits inside another unit's directory.

**Root package** = the unit path, 1:1 (the Kotlin rule gives the mapping). An `api` unit is laid out like any
other unit: its root package holds kinds, never loose files, however few contracts it has
(`…feature.profile.api.api.ProfileRepository`, `…feature.profile.api.model.Profile`,
`…nickname.api.usecase.RenameUseCase`).

**Scaffold: Gradle.**

1. Add the unit to `settings.gradle.kts` in the style the file already uses (`include(":modules:nickname")`).
2. Copy `build.gradle.kts` of the closest sibling unit of the same shape; keep its convention plugins, replace its
   dependencies with the new unit's.
3. Leave the explicit API mode off: public declarations carry no modifier.
4. Create `src/main/kotlin/<root package path>/` and `src/test/kotlin/<root package path>/`.
5. Add the dependency where the unit is consumed: `implementation(projects.modules.nickname)`; an `impl` unit is
   consumed only by the composition root.
6. Construct the unit's DI module in `di/RootModule.kt` of the application unit.
7. Build the unit and its consumers (`./gradlew :modules:nickname:build`, or the project's usual task).

**Scaffold: Cargo.**

1. Create `<container>/<name>/Cargo.toml` from the closest sibling crate (keep its workspace inheritance).
2. Add the crate to `[workspace] members` unless a glob already covers it.
3. Write `src/lib.rs` as the Rust rule shows: crate docs, the three lint attributes, the module blocks, the test
   block.
4. Add the path dependency where the crate is consumed and construct its DI module there.
5. Run `cargo clippy --all-targets -- -D warnings` and `cargo test -p <name>`.

### 4.2 Sub-concepts

Applied to the files the task creates inside one concept.

1. Give every contract (an interface or trait, or a class other packages call) a group: the contract; its
   implementations; the models and errors of this concept written directly in its function signatures (parameter
   and return types, with `Result`, `List`, `Flow`, `Option`, `Map` unwrapped) and the error types its
   implementations return; the files only its implementations use (tables, rows); a DI module that wires only
   these files. A type reachable only through another type's fields (`LinkResponse.Linked(val player: …)`) does
   not join.
2. Groups that share a file (one implementation class of two contracts, one model in two contracts' signatures)
   are one group.
3. A file in no group (a use case, command, listener, view model, config) joins a group when everything its
   constructor takes from this concept belongs to that group; otherwise it joins the main group. A screen or menu
   joins its view model's group.
4. The **main group** is the one whose contract carries the concept's noun (`LinkApi` in `link`), otherwise the one
   the concept's DI module exposes. Its files stay in the concept's own kinds.
5. Every other group with **≥ 3 files in ≥ 2 kinds** becomes a sub-concept `<concept>/<name>/`, with its files in
   its own kind packages. Smaller groups stay in the concept's own kinds.
6. **Existing files count, and a group is never split.** When a group already has files in the concept, new files
   of the group go where those are. When old and new files together reach the threshold and no sub-concept exists,
   the final message suggests it; the task does not create it for the new files alone.
7. **A refactor the user asked for decides every old sub-concept again, by its size.** All files count as new, so
   steps 1–5 run over the whole concept, but an old package that groups files under a domain noun (a sub-concept,
   or a top-level package of a one-feature unit) is decided by the number of its files, not by step 5:
   - **3 or more files: it stays**, its files split into kinds, even when they are all one kind.
     `limbo-packet/src/play/` with 20 packets becomes `play/model/`; `plugin/file/` with three world-file readers
     and their registry becomes `file/internal/`; `packets/c2s/` and `packets/s2c/` stay apart. A domain grouping
     a reader already relies on is worth one extra directory level.
   - **1 or 2 files: it is dissolved** into its parent's kinds. `onboarding/check/command/CheckCommand.kt` becomes
     `onboarding/command/CheckCommand.kt`, and a contract alone in its sub-concept (`audience/api/KAudience.kt`)
     becomes `api/KAudience.kt` of the parent.
   - The one exception is mirroring: when sibling units implement the same concept (`core`, `core-bukkit`,
     `core-minecraft`) and the concept is kept in at least one of them, it keeps its sub-concept in all of them, so
     the matching path finds the implementation (`core/…/location/{api,model}/` and
     `core-bukkit/…/location/mapping/`).

   Screens follow §4.3 regardless.

**Name**, first rule that yields one:

1. the word the task or the user uses for the group ("roles" → `role`);
2. in a refactor, the package the files already live in;
3. the contract's name without the concept's own noun (`Link`, `Linked`, `Linking`) and without `Api`, `Impl`,
   `Dao`, `Repository`, `Service`, `Gateway`, `Client`, `Module`, `Model`, `Entity`; the remaining words
   concatenated, singular, lowercase (Rust: `snake_case`). `CodeApi` → `code`; `PermissionGroups` →
   `permissiongroup`; `CodeValidator` in `code` → `validator`. When nothing remains, apply the same to the model the
   contract returns: `LinkingDao` → `LinkedPlayerModel` → `player`.

### 4.3 Screens

A screen is a UI entry with its own view model: a Compose screen, a menu, a view. When a concept has ≥ 2 screens,
each screen is a sub-concept, whatever its size, holding its `viewmodel/` and its `composable/` (or `menu/`,
`view/`). Name: the screen's type name without the concept's noun and without `Screen`, `ViewModel`, `Menu`
(`EditProfileScreen` → `edit`); `overview` when nothing remains. A concept with one screen keeps it in its own
`viewmodel/` and `composable/`.

### 4.4 Layers

A concept the task creates gets layers when all four hold, counted in the plan after sub-concepts and screens are
decided:

- its own kinds and sub-concepts number **≥ 10**;
- its own kinds hold **≥ 20 files**;
- it has `usecase/` or a domain-role kind (`check/`, `policy/`);
- it has `database/`, `network/`, `storage/` or a system kind.

It also gets them when the user asks («сделай по clean architecture»), and a concept that already has layers
keeps them: new files follow its layers. Below the trigger nothing is layered, split or reported.

| Layer | Holds |
|---|---|
| `domain/` | `api`, `model`, `usecase`, domain-role kinds |
| `data/` | `database`, `network`, `storage`, `config`, system kinds, and the `internal` implementations of domain contracts |
| `presentation/` | `command`, `argument`, `event`, `menu`, `composable`, `view`, `viewmodel`, `permission`, and screen sub-concepts |
| concept level | `di/`, `util/` |

`mapping/` goes to the layer of its callers. A layer holds kind packages and screen sub-concepts, never files and
never another layer. A unit root that holds ≥ 2 concepts never holds a layer.

### 4.5 Gates

- **A1 interface.** Declare an interface only when another concept or unit calls it, when ≥ 2 implementations
  exist or are created now, or when a test replaces it with a fake (I/O a consumer's test must not perform).
  Otherwise write the concrete class in its kind.
- **A2 conversion.** Put a conversion where both types are visible without a new dependency: an extension in the
  source type's file when its unit already sees the target type; otherwise a `private` extension in the file of
  its only caller; with ≥ 2 callers, a `mapping/` file in the caller's unit and concept. Never add or reverse a
  dependency to place a conversion.
- **A3 use case.** A `usecase/` class only when the operation decides something (a rule, a branch on state) or
  combines ≥ 2 contracts. A use case that forwards one call is replaced by the call.
- **A4 DI module.** A concept gets its own DI module when it has ≥ 2 services to wire; otherwise the parent
  concept's or the unit's DI module wires it.

### 4.6 A role no row names

1. Re-read the kind table from the top. Most new roles are rows in disguise: a Redis client is `storage`, a gRPC
   stub is `network`, a Brigadier node is `command`, a YAML messages file is `config`.
2. **Reuse.** If a package in this unit already holds files of the same role (same type-name suffix, same
   framework base type), use its name.
3. **Framework role.** When ≥ 2 files of the concept extend the same framework base type, implement its interface
   or carry its annotation, the kind is the framework's singular noun for that role: `placeholder` (PlaceholderAPI
   expansions), `task` (scheduled tasks), `migration`, `serializer`.
4. **Domain role.** When ≥ 2 files of the concept end in the same role noun no row names (`…Check`, `…Policy`,
   `…Rule`), the kind is that noun: `check`, `policy`.
5. **One file** of a new role goes to `internal/`; its type name carries the role.
6. Look the name up in the replacement table; a banned spelling is replaced by its row.
7. Report it in the final message: `new kind: policy — rules a clan action must pass, 3 files`. The rule files are
   never edited by the task.

**Replacement table** (package names below a unit's root package; unit names such as `core`, `shared`, `gui`,
`data`, `dao` are outside it):

| Instead of | Use |
|---|---|
| `models`, `entity`, `entities`, `types`, `domain` or `data` as a kind | `model`; `database` for database rows |
| `error`, `errors`, `exception`, `exceptions`, `failure` | `model` |
| `implementation`, `service`, `services`, `manager`, `controller`, `handler`, `provider`, `helper`, `helpers` | `impl` for a public implementation (Rust: `imp`, since `impl` is a keyword), `internal` for one its unit keeps, `api` for its contract, `usecase` for an operation |
| `interfaces`, `contract`, `port`, `ports` | `api` |
| `dto`, `dtos`, `remote`, `client`, `http` | `network` |
| `dao`, `repository`, `persistence`, `db`, `table`, `exposed`, `room` | `database` for the implementation, `api` for the contract |
| `krate`, `prefs`, `datastore`, `file` | `storage` |
| `configuration`, `settings`, `properties`, `translation`, `messages` | `config` |
| `ui`, `gui`, `screen`, `screens`, `compose`, `component`, `components` | `composable`, `menu` or `view` |
| `presentation` or `presenter` as a kind, `state` | `viewmodel` for UI state, `model` for domain state |
| `mapper`, `mappers`, `converter`, `converters` | `mapping` |
| `utils`, `common`, `misc`, `core`, `ktx`, `ext`, `extensions` | `util` |
| `listener`, `listeners`, `events` | `event` |
| `commands`, `cmd`, `argumenttype`, `arguments` | `command`, `argument` |
| `jda`, `kord` | `discord` |

`util/` sits at `<concept>/util/` when ≥ 2 kinds of that concept use the helper and at `<unit root>/util/` when ≥ 2
concepts do; a helper one file uses is a `private` function in that file. A helper whose name carries a domain noun
is not `util`: it goes to its kind or to `internal/`. A helper over one value of a type is an extension of that type
named without a domain noun (`Throwable.describe()`, not `describeConfigError(error)`), so a generic helper never
hides in a domain kind under a domain name.

### 4.7 Caps

| What | Rule |
|---|---|
| files in a kind package | no cap; above 20 the final message reports the package with a suggested split |
| lines in a file | split above 400, by a whole group |
| lines in `lib.rs` | about 300 (about 100 files): split the crate; a new crate is split at plan time |
| depth | no limit |
| a concept's child packages | an input to the layer trigger only |

### 4.8 New files in old packages

| The package a new file enters, before the task | Where the new file goes |
|---|---|
| holds only files (an old flat `link/code/`) | into the kind package the rules give, created inside it; the old files stay and their moves are reported |
| holds only packages | into its kind package, created when missing |
| holds files and packages | into its kind package; the old loose files stay and are reported |
| has a package for the file's role under another spelling (`commands/`, `utils/`, `impl/`, `exception/`) | into that package |
| is a new sub-concept in a unit that names the file's role with another word (DAO implementations in `impl/`) | into a kind package with that word (`nickname/impl/`); the contract still goes to `nickname/api/` |
| is a Rust module declared by `mod.rs` or `foo.rs` | declared in that module's file |

Editing an old file in place is part of the task: a new variant goes into the old sealed type's file, a new
service into the old DI module.

## 5. Worked examples

### 5.1 A one-unit plugin: nicknames (L1)

Task: a new Bukkit plugin in which players set a nickname with `/nick <name>` and reset it with `/nick reset`;
nicknames are stored in the database, shown in chat, and limited by a length and a colour list in the config.

Decisions: a single-unit project and no B2/B3, so one unit. The unit is one feature, so kinds sit at its root.
One contract group (`NicknameDao`), 7 children, 11 files: L1. `NicknameDao` passes A1 (the command tests fake
it). The row → model conversion has one caller: a private extension in `ExposedNicknameDao.kt`. One service to
wire besides the root: no concept DI module (A4); `RootModule` wires it.

```
src/main/kotlin/ru/astrainteractive/nickname/
├── NicknamePlugin.kt                  entry point, public
├── di/RootModule.kt                   internal
├── api/NicknameDao.kt                 internal interface
├── model/
│   ├── Nickname.kt                    data class + nested Style
│   └── NicknameError.kt               sealed, every variant in the file
├── database/
│   ├── NicknameTable.kt
│   └── ExposedNicknameDao.kt
├── config/NicknameConfig.kt           max length, allowed colours
├── command/
│   ├── NickCommand.kt                 /nick <name> and /nick reset
│   └── NickTabCompleter.kt
└── event/ChatNicknameListener.kt
src/test/kotlin/ru/astrainteractive/nickname/
├── command/NickCommandTest.kt
└── fake/FakeNicknameDao.kt
```

### 5.2 A refactor the user asked for: TelegramBridge `modules/link`

Every file counts as new. `modules/link` is one feature, so its root package `…messagebridge.link` holds kinds and
sub-concepts. Contract groups: `LinkApi` (main; `Unlinking` and `DiscordMembership` merge into it because
`LinkApiImpl` implements all three), `CodeApi` (3 files, 3 kinds), `LinkingDao` + `DiscordLinkedPlayerDao` (merged:
both signatures name `LinkedPlayerModel`; 8 files), `PermissionGroups` (4 files, the error its implementations
return included). Names from the existing packages: `code`, `player`, `role`.

```
…/messagebridge/link/
├── api/LinkApi.kt, Unlinking.kt, DiscordMembership.kt       public: other units call them
├── model/LinkResponse.kt, UnlinkResponse.kt                 sealed families, one file each
├── internal/LinkApiImpl.kt
├── mapping/LinkResponseMapper.kt
├── di/LinkModule.kt
├── code/
│   ├── api/CodeApi.kt
│   ├── model/CodeUser.kt
│   └── internal/CodeApiImpl.kt
├── player/
│   ├── api/LinkingDao.kt (public), DiscordLinkedPlayerDao.kt (internal)
│   ├── model/LinkedPlayerModel.kt (nests DiscordLink, TelegramLink), LinkedPlayerStorageError.kt
│   ├── database/LinkedPlayerTable.kt, LinkedPlayerRows.kt, LinkingDaoImpl.kt
│   └── di/LinkDatabaseModule.kt
└── role/
    ├── api/PermissionGroups.kt
    ├── model/PermissionGroupError.kt
    └── internal/LuckPermsGroups.kt, DiscordLinkRole.kt      one adapter per system: no system kind
link/src/test/kotlin/…/link/internal/LinkApiImplTest.kt
link/src/testFixtures/kotlin/…/link/player/fake/FakeLinkingDao.kt   used by command and messenger tests
```

### 5.3 New files in an old package: `CodeValidator` and an old `commands/`

The old `link/code/` holds `CodeApi.kt`, `CodeApiImpl.kt`, `CodeUser.kt` loose. The task adds code validation.

- A validator with a contract, an implementation and a result type is a group of 3 files in 3 kinds, so it is a
  sub-concept: `link/code/validator/api/CodeValidator.kt`, `link/code/validator/internal/DefaultCodeValidator.kt`,
  `link/code/validator/model/CodeValidation.kt`.
- A validator that is one concrete class (pure logic, so A1 gives it no interface) goes to
  `link/code/internal/CodeValidator.kt`, its result type to `link/code/model/CodeValidation.kt`.

Either way the three old files stay; the final message suggests `CodeApi.kt → code/api/`, `CodeApiImpl.kt →
code/internal/`, `CodeUser.kt → code/model/`.

In the old `modules/command` unit, whose root package is `…messagebridge.commands`, a new command goes to
`…commands/<feature>/`, not to a new `command/` package next to it.

### 5.4 An app feature across units: profile

Task: a profile feature in an Android Compose app with an overview screen and an edit screen, loaded over REST
and cached in the app's Room database, which the `core/database` unit owns. The chat feature shows the profile's
avatar.

Decisions: app project, so `api` + `impl` (always). The cache entity and its Room DAO go to the owner unit
`core/database`, as a leaf concept (both files import Room). Two screens, so two screen sub-concepts. The entity →
`Profile` conversion has one caller in another unit: a private extension in `ProfileRepositoryImpl.kt` (A2).
`impl` has 6 children and 9 files: L1.

```
feature/profile/api/src/main/kotlin/com/example/feature/profile/api/
├── api/ProfileRepository.kt           public interface
└── model/Profile.kt, ProfileRoute.kt  public data class + nested Avatar; public navigation key
feature/profile/impl/src/main/kotlin/com/example/feature/profile/impl/
├── network/ProfileClient.kt, ProfileDto.kt
├── internal/ProfileRepositoryImpl.kt
├── usecase/UpdateNicknameUseCase.kt   validates the nickname, then saves
├── overview/
│   ├── viewmodel/ProfileOverviewViewModel.kt
│   └── composable/ProfileOverviewScreen.kt
├── edit/
│   ├── viewmodel/EditProfileViewModel.kt    state and intents in the same file
│   └── composable/EditProfileScreen.kt
└── di/ProfileModule.kt                public: the app's RootModule constructs it
core/database/src/main/kotlin/com/example/core/database/profile/ProfileCacheEntity.kt, ProfileCacheDao.kt
feature/profile/api/src/testFixtures/kotlin/com/example/feature/profile/api/fake/FakeProfileRepository.kt
feature/profile/impl/src/test/kotlin/com/example/feature/profile/impl/edit/viewmodel/EditProfileViewModelTest.kt
```

### 5.5 A large plugin feature: clans (L2)

Task: players create clans, invite and promote members, pay into a clan bank through Vault; commands, a
clan-chat listener, a friendly-fire listener, a config and translations. The project's feature units own their
databases (no data unit), so the feature is a new unit `modules/clan` (B1).

Plan counts: one contract group besides two files of the economy adapter; 10 children (`api`, `model`, `database`,
`usecase`, `policy`, `config`, `command`, `event`, `internal`, `di`), 25 files, use cases and a domain kind, a
database: the layer trigger fires.

```
modules/clan/src/main/kotlin/ru/astrainteractive/clan/
├── domain/
│   ├── api/ClanRepository.kt, EconomyGateway.kt
│   ├── model/Clan.kt (nests Member and its Rank), ClanInvite.kt, ClanError.kt
│   ├── usecase/CreateClanUseCase.kt, InviteMemberUseCase.kt, AcceptInviteUseCase.kt,
│   │           PromoteMemberUseCase.kt, DepositToBankUseCase.kt
│   └── policy/ClanNamePolicy.kt, MemberLimitPolicy.kt, RankPolicy.kt     new kind, reported
├── data/
│   ├── database/ClanTable.kt, ClanMemberTable.kt, ClanInviteTable.kt, ExposedClanRepository.kt
│   ├── config/ClanConfig.kt, ClanTranslation.kt
│   └── internal/VaultEconomyGateway.kt
├── presentation/
│   ├── command/ClanCommand.kt, ClanTabCompleter.kt
│   └── event/ClanChatListener.kt, FriendlyFireListener.kt
└── di/ClanModule.kt                   public: instances/bukkit RootModule constructs it
```

The nicknames plugin of §5.1, at 7 children and 11 files, stays flat under the same rule.

### 5.6 A new Rust crate in a workspace: afk

Task: mark idle players as away after a configured timeout, announce it, and let `/afk` toggle it. The workspace
has `library/core` (with a `Clock` trait) and `library/core-test-support` (with `FakeClock`), and one crate per
feature under `modules/`.

Decisions: multi-crate workspace, independent feature, so a new crate `modules/afk` (B1). One concept: kinds at the
crate root. Only `di::AfkModule` is `pub` (the server instance constructs it). The tracker uses core's `Clock`, so
its test takes `FakeClock` from `core-test-support` instead of a local copy.

```
modules/afk/
├── Cargo.toml                         [dev-dependencies] core-test-support
├── src/lib.rs                         the only module root; test block last
├── src/command/afk_command.rs
├── src/config/afk_config.rs
├── src/di/afk_module.rs               pub struct AfkModule
├── src/event/activity_listener.rs
├── src/internal/activity_tracker.rs   decides away / back from the last activity
├── src/model/afk_transition.rs        enum WentAway / CameBack / Unchanged
└── test/internal/activity_tracker_test.rs
```
