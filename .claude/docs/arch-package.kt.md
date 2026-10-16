## Kotlin: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Kotlin and Gradle express it.

### Packages and directories

- The directory is the package: `src/main/kotlin/ru/astrainteractive/aspekt/module/jail/data/JailRepository.kt`
  declares `package ru.astrainteractive.aspekt.module.jail.data`.
- A unit's root package is the project's base package followed by the unit's path with hyphens removed. The
  container directory's segment follows the project's existing convention: AspeKt keeps it in the singular
  (`modules/jail` → `ru.astrainteractive.aspekt.module.jail`), BUSY keeps it as is
  (`components/bsb/monetization/impl` → `com.flipperdevices.bsb.monetization.impl`); a new project drops it.
  An Android unit's `namespace` is its root package.
- The words `api` and `impl` appear in a package only as the segment of a unit named so; they are never a
  package of their own.
- Platform code of a Multiplatform unit goes to its source set (`androidMain`, `iosMain`, `jvmMain`) at the
  same package path, never to a package named after the platform. `expect` sits in `commonMain` in the role
  that owns the concept; each `actual` sits at the same path in its source set, in a file with the platform
  suffix (`Clipboard.android.kt`). A platform source set may hold types that exist only for that platform. The
  shared code is a library; each platform's application is an entry-point unit of its own; there is no
  `sharedLogic` or `sharedUI` unit.

### Visibility

Kotlin has no package-private visibility: the package organises, only the file and the unit encapsulate.
Decide the tier while writing the declaration:

| Declaration | Modifier |
|---|---|
| used by one file only | `private` in that file |
| used by other files of the same unit | `internal` |
| used by another unit: the contents of an `api` unit, a DI module the entry point constructs, a `<Context>Api` and the models in its signatures, the platform main class of an entry-point unit | none (public) |

Public is Kotlin's default, so a public declaration carries no modifier. The keyword `public` is written
only in a library unit with explicit API mode on, where the compiler demands it, and nowhere else. Class
members are `private` unless another class uses them. Entry points such as `JailCommand` and `JailEvent` are
`internal`: the entry-point unit constructs the context's DI module, not its classes. The `test` source set sees `internal`, so nothing
is widened for tests.

```kotlin
// jail/data/file/FileJailRepository.kt: used by JailModule in the same unit
internal class FileJailRepository(
    private val folder: File,
    private val format: StringFormat
) : JailRepository
```

- A published library unit (AstraLibs) switches explicit API mode on (`kotlin { explicitApi() }`) so that
  every public declaration there is deliberate. Application and plugin units never switch it on.
- A declaration one library unit needs from another, but no consumer of the library should use, is public and
  marked with an opt-in annotation (`@RequiresOptIn` marker such as `InternalAstraLibsApi`), never placed in a
  package named `internal`.

### Units and Gradle

- A unit's logical name equals its physical location; a container directory is never included as a project of
  its own. The root project holds no sources. Build logic lives in an included `build-logic` build with one
  convention plugin per unit type, applied only where needed, never through `subprojects`. Dependencies are
  declared with `implementation`; `api` only for a type exported through a Multiplatform framework. These
  apply to new units; old `include(":modules:jail")` paths stay.
- An `api` unit may depend on `core`, the domain kernel and other `api` units, never on any `impl`. Only the
  entry-point unit depends on `impl` units, and only to construct the composition root. A consumer context
  depends on the provider's `api` unit, or on its root package when the provider is not split.
- An `api` unit holds the `<Context>Api` contract, the models in its signatures, the stubs or preview
  implementations of its own contracts under `<contract package>/stub/`, and, when the entry point constructs
  the context through an interface as the DI rule allows, that DI-module interface; its implementation in
  `impl/di` is the `Default…` case.
- A `<context>/contract` unit holds only `@Serializable` types and route constants shared by a server unit and
  its client unit; neither side's `model` crosses the wire.
- Every unit has a one-sentence `README.md`.

### Entry points, use cases and the platform

- Entry points sit directly under the context, one role per mechanism that invokes them: `command`,
  `event`, `service` (a component the platform runs, such as an `IntervalService` task), `route` (a Ktor
  route and its request and response types), `job`, `composable`, `viewmodel`. These roles and every
  technology package may import the platform (Bukkit, Ktor, Compose).
- A use case is a class at the context root named by its verb (`FreeInmate`) with one public
  `operator fun invoke`, no interface. The one class implementing the context's `<Context>Api`,
  `Default<Context>Api`, sits at the root with the use cases and delegates to them. It and every contract import no platform or framework type; the server
  is reached through AstraLibs' abstractions (`server/player`, `server/location`, `server/permission`) or the
  context's own `integration` contract.
- A screen is a `composable` plus its own `viewmodel`; a view model holds no rule and calls use cases and
  contracts; analytics and state shared between screens stay in the presentation roles; the shared design
  system is a `core` capability.

### DI modules

`di/` exists at the context level and at the level of a module of a context, and holds exactly one DI module
class. A role package never has a `di/` of its own: the command wiring of `jail` is part of `JailModule`, not
a `jail/command/di/JailCommandModule`. The entry-point unit's `RootModule` lists the context modules
explicitly; there is no scanning.

### What goes in one file

- A file holds one type family; the sealed type and its variants come first and share the file.
- A new data class that is a property type of exactly one class is nested in it. A type returned to another
  class is a top-level family in `model`.
- An `enum` used only through one type is nested in it; otherwise it is a top-level family of its own.
- Same file as the type: its companion object, private helpers, and the extension functions every client of
  the type uses. Never a class inside a function body, never an `inner class`.
- A file of top-level functions is named after what they do (`DurationFormat.kt`), never `Utils.kt`; helpers
  are never grouped in an `object`.
- Multiplatform platform files carry the source-set suffix (`Platform.jvm.kt`).

### Tests

- `src/test/kotlin` mirrors `src/main/kotlin` package for package; `commonTest` mirrors `commonMain`, each
  platform test source set mirrors its main source set. A test file is named after the owner of the behaviour
  it checks (a use case, a repository implementation, a model rule, an entry point); a class with no behaviour
  of its own gets no test file.
- A `Fake…` scripts failures or records calls. It lives in the test tree in `fake/` inside the concept of
  the contract it replaces (`src/test/kotlin/…/jail/data/fake/FakeJailRepository.kt`). A double that only
  stores values in memory is not a fake but an in-memory implementation: production code in `data/memory/`,
  usable by any unit's tests and by demos.
- A fake that tests of other units need lives in the `testFixtures` source set of the owning unit at the same
  path (`java-test-fixtures` for JVM units, `android { testFixtures { enable = true } }` for Android units),
  consumed with `testImplementation(testFixtures(projects.modules.jail))`. A Multiplatform unit has no
  `testFixtures`: its shared fakes go to a sibling unit `<feature>/fake`.
- Three suites: in each context's unit, model rules tested directly, use cases with fakes or in-memory
  implementations, technology packages against the real technology where it runs in a test (Exposed on an
  embedded database, a krate on a temporary directory); in the entry-point unit, integration tests of the
  wired application; architecture tests as their own suite.
