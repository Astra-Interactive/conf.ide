---
name: package-layout
description: Plan and review where new source files, packages and build units go in Kotlin and Rust projects. Use before creating the first new file of any task (feature, bugfix, refactor, test) and whenever a task may need a new package, Gradle module or Cargo crate. Gives the planning procedure, the decision tests, the new-role procedure, worked examples and the review checklist.
version: 2.0.0
---

# Package layout

The rules `arch-package.md`, `arch-domain.md` and `arch-context.md` (with their `.kt.md` and `.rs.md`
companions) say what a finished tree looks like. This skill is the procedure for getting there and the
checklist for proving it. Read the rules first; this file does not repeat them.

## 1. Before the first new file

1. Record `BASE=$(git rev-parse HEAD)`. The review at the end lists the files added since it.
2. Read the one-sentence `README.md` of every unit you are about to touch. If a unit has none, write it as the
   first file of the task.
3. Answer the decision tests of section 2, in order, for the feature as a whole. Write the answers down as
   one line each; they go into the final message.
4. Print the planned tree: every new file with its full path, every new package, every new unit with its
   `build.gradle.kts` or `Cargo.toml`. A tree that shows a forbidden package name, a loose file at a context
   root that is not a use case, or an `api` unit holding logic is wrong before any file exists.
5. Only then create files. Create a role package the moment its first file exists, never before.

## 2. Decision tests

Each test is answered yes or no. The first test that applies decides.

**T1. Which unit?**
- Does the file belong to an existing context, judged by its words and the data it touches? Then that unit.
- Is it the platform main class or the composition root? The entry-point unit.
- Is it platform infrastructure that knows no domain word, and needed by a second context? `core`, as a
  capability-named package inside it.
- Is it a typed identifier or a generic value object two contexts share? The kernel.
- Is it a serializable wire type a server and its client both need? The `<context>/contract` unit.
- Otherwise it is a new context (T2).

**T2. Is this a new context or a module of an existing one?**
A context when all three hold: its data, if any, is its own; it has words of its own; a typical change to it
stays inside it. Otherwise it is a module of the context that owns the data it touches. A new context is a new
unit in any project with more than one context (Kotlin); in Rust, a new top-level module block.

**T3. Does the context split into `api` and `impl`?**
Only when another context depends on it, or when it has two or more platform units. Platform units
(`<context>/bukkit`) only for separate Gradle JVM builds; Multiplatform uses source sets.

**T4. Which role?**
Name the file by what the platform or the context does with it: invoked by the command framework → `command`;
by the event bus → `event`; by the scheduler or lifecycle → `service`; by the HTTP router → `route`; by the
UI → `composable`, `viewmodel`; the context's own types, errors, results, events → `model`; a repository
contract → `data`, its implementation → `data/<technology>`; what the context needs from another system →
`integration`, its implementation → `integration/<system>`; a shared conversion → `mapping`; an extension
that is not part of a type → `util` or the type's file; wiring → `di`; a verb that decides or combines two
contracts → the context root. If no role fits, go to section 3.

**T5. Does this need an interface?**
Yes on exactly four triggers: another unit calls it; two or more implementations exist or one is known to
come; an inner part declares what it needs from an outer one; a test must replace a contract over I/O or the
platform with a fake. Pure logic, entities and use cases: no.

**T6. Does this need a use case?**
Only when the entry point would have to decide something or combine two or more contracts. A command that
reads or writes one repository calls it directly.

**T7. Is this an anti-corruption layer?**
Mandatory when the provider's model is not yours: an external library, a platform API, a remote system, a
third-party plugin. Optional for a sibling context, whose `<Context>Api` is used directly by default.

**T8. Does this go into a shared unit?**
Only on its second consumer, and never if it holds business logic.

**T9. One file or several?**
One type family per file; a sealed type with its variants in one file; a data class used by exactly one class
nested in it; split only above about 400 lines.

**T10. Where is it tested?**
A model rule directly; a use case with fakes or an in-memory implementation; a technology package against the
real technology in a test; the wired application in the entry-point unit; the layout by the architecture
suite.

## 3. A role no row names

When T4 finds no role: name the package by what the platform or the context does with the file, singular, one
word, never a pattern name (`usecase`, `repository`, `factory`), a kind name (`dto`, `exception`, `helpers`) or
a layer name (`domain`, `presentation`). Use it for the task, and in the final message report the new role,
the files in it and why no existing role fits, so that the menu in `arch-package.md` can be extended or the
file moved.

## 4. Worked examples

Each tree is what the rules produce for a new feature of that kind. Old files in the real projects are not
moved to match.

### A plugin context (AspeKt, `jail`)

```
modules/jail/                                   one unit: nothing else depends on jail
  README.md                                     "Jails players for a sentence and frees them when it ends."
  src/main/kotlin/ru/astrainteractive/aspekt/module/jail/
    JailPlayer.kt                               use case: finds the jail, teleports, records the inmate
    FreeInmate.kt                               use case: frees, teleports back
    command/JailCommand.kt                      the command framework invokes it
    event/JailEvent.kt                          the event bus invokes it
    service/UnJailServiceTask.kt                the scheduler invokes it; calls FreeInmate
    model/Jail.kt  model/JailInmate.kt  model/JailLocation.kt  model/JailError.kt
    data/JailRepository.kt                      the contract
    data/file/FileJailRepository.kt             the implementation, named by what it uses
    data/memory/InMemoryJailRepository.kt       production code, for tests and demos
    integration/EconomyCharger.kt               what jail needs from economy, in jail's words (optional ACL)
    integration/economy/EconomyApiCharger.kt    the adapter over economy's EconomyApi
    di/JailModule.kt                            one DI module, command wiring included
  src/test/kotlin/ru/astrainteractive/aspekt/module/jail/
    FreeInmateTest.kt  model/JailInmateTest.kt  data/file/FileJailRepositoryTest.kt
    data/fake/FakeJailRepository.kt
```

### A split context in an app (BUSY, `monetization`)

```
components/bsb/monetization/                    container, no build file
  api/   README.md                              "Tells whether the user may use paid features and sells plans."
    …/monetization/api/MonetizationApi.kt       the one published interface
    …/monetization/api/model/Plan.kt            models in its signatures
    …/monetization/api/stub/StubMonetizationApi.kt
  impl/  README.md
    …/monetization/impl/CheckEntitlement.kt     use case at the root
    …/monetization/impl/composable/…  viewmodel/…   screens, one view model each
    …/monetization/impl/model/…
    …/monetization/impl/data/EntitlementRepository.kt
    …/monetization/impl/data/revenuecat/RevenueCatEntitlementRepository.kt
    …/monetization/impl/offer/{composable, viewmodel, model}/   a module of the context
    …/monetization/impl/di/MonetizationModule.kt
    src/androidMain/…/monetization/impl/data/revenuecat/BillingClient.android.kt   actual for the platform
```

### A library capability (AstraLibs, `encoding` inside `core`)

```
core/  README.md                                "Platform-free building blocks every plugin uses."
  …/astralibs/encoding/Encoder.kt               the contract
  …/astralibs/encoding/base64/Base64Encoder.kt  named by what it uses
  …/astralibs/encoding/model/Encoded.kt
build.gradle.kts: kotlin { explicitApi() }      a published library: every public declaration is deliberate
```

### A Ktor context with a client (AstraLearner, `dictionary`)

```
modules/dictionary/contract/                    wire types both sides compile against
  …/dictionary/contract/WordDto.kt  …/contract/DictionaryRoutes.kt
modules/dictionary/                             the server context
  …/dictionary/AddWord.kt                       use case
  …/dictionary/route/WordRoutes.kt              the router invokes it; request and response types live here
  …/dictionary/model/Word.kt  …/model/DictionaryError.kt
  …/dictionary/data/WordRepository.kt  …/data/exposed/ExposedWordRepository.kt  …/data/exposed/table/WordTable.kt
  …/dictionary/di/DictionaryModule.kt
```

### A Rust crate (a plugin, `jail` as a context block)

```
crates/plugin-jailer/
  README.md
  src/lib.rs                                    the whole module tree as inline blocks, no code
  src/jail/free_inmate.rs                       use case struct
  src/jail/free_inmate_tests.rs                 sibling test, declared from lib.rs
  src/jail/model/jail.rs  src/jail/model/inmate.rs
  src/jail/data/repository.rs                   trait JailRepository
  src/jail/data/file.rs                         FileJailRepository
  src/jail/command/jail.rs
  src/jail/di/jail_module.rs
```

## 5. Before the final message

List the files added since `BASE` (`git diff --name-only --diff-filter=A $BASE`) and answer each item in one
line. A "no" is fixed by moving the new file, never an old one.

1. Does every new unit have a one-sentence `README.md`, and does the sentence fit?
2. Is every new unit a context, an entry point, `core`, the kernel or a `<context>/contract`?
3. Is the first level under every unit's root a capability, with no layer or kind name?
4. Is every loose file at a context root a verb-named use case with one public entry and no interface?
5. Is every other new file in a role from the menu, and is every role package non-empty?
6. Does any new package carry a forbidden name (`domain`, `api`, `impl`, `internal`, `usecase`, `repository`,
   `exception`, `dto`, `util` at the top, `port`, `adapter`, …)? Are all package names singular?
7. Does every contract sit at its role level with its implementation one level down in a package named by its
   technology or system?
8. Is every implementation named by technology or variant, with no `Impl`, `I` prefix or `Interface` suffix?
9. Does every new interface pass one of the four triggers?
10. Does `model` import nothing from the context and no platform or ORM type (serialization annotations
    excepted)? Do use cases and contracts import no platform type?
11. Does every data class that is a property of exactly one class sit nested in it? Does every sealed family
    sit in one file in `model`? Is every error family in `model`, with no `exception` package?
12. Does every new context own its data, and does no context read another's tables or files?
13. Does every cross-context edge go through a `<Context>Api`, an event or a typed identifier, with no cycle and
    no `api` → `impl` dependency?
14. Is every dependency on an uncontrolled provider behind an `integration` contract with its implementation
    under `integration/<system>`?
15. Did anything enter `core` or the kernel before its second consumer, or any business logic at all?
16. Is `di/` present only at the context and module levels with exactly one DI module each?
17. Are the three visibility tiers applied, with no written `public`, and explicit API mode on only in library
    units?
18. Are tests mirrored package for package, fakes in `fake/`, in-memory implementations in `data/memory`?
19. Rust: is every module declared from `lib.rs`, no `mod.rs`, no `foo.rs` beside `foo/`, every file module
    private and re-exported by name, tests in sibling `_tests.rs` files, `unreachable_pub` on?
20. Did the task leave every old file where it was, and does the final message list the old files the rule
    would move?

The checker that runs items 3, 5, 6, 7, 8, 10, 13 and 19 mechanically is defined in the checker stage of the
rewrite; until it exists, answer them by hand and say so.
