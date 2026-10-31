## Kotlin: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Kotlin and Gradle express it.

### Packages and directories

- The directory is the package:
  `modules/data/dao/src/main/kotlin/ru/astrainteractive/astrarating/data/dao/rating/api/RatingRepository.kt`
  declares `package ru.astrainteractive.astrarating.data.dao.rating.api`.
- A unit's root package follows the project's existing convention, and a new unit takes the root package its
  neighbours would give it: AspeKt keeps the container in the singular (`modules/jail` →
  `ru.astrainteractive.aspekt.module.jail`), an app keeps the path after its container
  (`components/shop/payment/impl` → `com.example.shop.payment.impl`), AstraRating drops the platform suffix
  (`modules/event-bukkit` → `ru.astrainteractive.astrarating.event`). A new project uses the base package
  followed by the unit path with hyphens removed and the container dropped. An Android unit's `namespace` is
  its root package.
- `api` is both a unit name (`gui/api`) and a kind package (`rating/api`); `impl` is only a unit name, in
  apps. A word on the forbidden list may appear in a unit's root package (`…data.dao`, `…payment.impl`),
  never in a package created inside the unit.
- Platform code of a Multiplatform unit goes to its source set (`androidMain`, `iosMain`, `jvmMain`) at the
  same package path, never to a package named after the platform. `expect` sits in `commonMain` in the kind
  that owns the concept; each `actual` sits at the same path in its source set, in a file with the platform
  suffix (`Clipboard.android.kt`). A platform source set may hold types that exist only for that platform. The
  shared code is a library; each platform's application is an entry-point unit of its own; there is no
  `sharedLogic` or `sharedUI` unit.

### Visibility

Kotlin has no package-private visibility: the package organises, only the file and the unit encapsulate.
Decide the tier while writing the declaration:

| Declaration | Modifier |
|---|---|
| used only inside the file that declares it | `private` in that file |
| used by other files of the same unit, such as an implementation its DI module constructs | `internal` |
| used by another unit: the contracts, models, model rules and use cases of an `api` unit, the `stub` and `memory` implementations another unit uses, shared fakes exported to another unit's tests, a DI module another unit constructs, the classes the platform constructs in an entry-point unit | none (public) |

Public is Kotlin's default, so a public declaration carries no modifier. The keyword `public` is written
only in a library unit with explicit API mode on, where the compiler demands it, and nowhere else. Class
members are `private` unless another class uses them. Entry points such as `JailCommand` and `JailListener` are
`internal`: other units construct the unit's DI module, not its classes. The `test` source set sees `internal`, so nothing
in production is widened for same-unit tests. A fake exported through `testFixtures` or `<feature>/fake`
is public for its test consumers; an ordinary same-unit fake is `internal`.

```kotlin
// modules/jail/api: jail/file/FileJailRepository.kt, used by JailModule in the same unit
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
- In a plugin, an `api` unit (`gui/api`) holds the platform-free code of its sub-context that other units
  call: models, use cases, contracts and their platform-free implementations, with its own DI module. Its build file declares no
  platform dependency (no Paper, no Bukkit). The platform unit (`gui/bukkit`) depends on it and holds what
  imports the platform.
- In an app, an `api` unit holds contracts, the models in their signatures, the `util` rules of those models and
  stubs (`<concept>/stub/`); the `impl` unit holds the rest. Only the entry-point unit depends on an `impl` unit.
- Dependencies between units follow the second table of `arch-context.md`; nothing depends on the entry-point
  unit, and `core` depends on no feature unit.
- A `<context>/contract` unit holds only `@Serializable` types and route constants shared by a server unit and
  its client unit; neither side's `model` crosses the wire.
- Every unit has a one-sentence `README.md`.

### Entry points, use cases and the platform

- Entry points sit in kind packages named for the mechanism that invokes them, in the project's and the
  framework's words: `command`, `event`, `service` (an `IntervalService` task), `route` (a Ktor route), `job`.
  A task run once at start is `warmup`, a format converter `migration`, a failure handler `error`. UI kinds
  come from the UI framework: `composable` only with Compose, and the state holder by its class: `viewmodel`
  for an Android-style view model, `component` for a Decompose component; when a component holds a view model,
  each has its kind beside the other in the concept: `component` for the component (the state holder, with its
  interface when another unit opens it), `viewmodel` for the view model it holds
  (`offer/component/DefaultOfferComponent`, `offer/viewmodel/OfferViewModel`); for AstraLibs menus the
  project's words (AstraRating: `gui`, `slot`, `context`, `component`). Entry-point kinds and technology
  packages may import the platform; a `warmup` or `migration` in a platform-free unit reaches the server
  through AstraLibs' `PlatformServer`.
- A use case is `<Verb><Object>UseCase` (`AddRatingUseCase`) in the `usecase` package of its concept, with one
  public `operator fun invoke` and no interface, except an app's use case another unit calls (package-layout
  rule, Units 6). A use case and a contract import no platform or framework type (a state holder's interface
  may import its UI framework, Decompose's `ComponentContext`); the server is reached through AstraLibs'
  abstractions (`server/player`, `server/location`, `server/permission`) or the sub-context's own contract.
- A state holder of a menu or screen (`component` in AstraRating and in a Decompose app, `viewmodel` for a
  view model) holds no rule and calls use cases and contracts; the shared design system is the design-system
  unit (`core/ui`).

### DI modules

Each unit that assembles dependencies has its own DI module in the `di` package of the level it wires, and a
resource with its own lifecycle has its own DI module in the unit that owns it. A unit of contracts and
models only has none; declaring fakes that tests construct directly needs none either. References between
DI modules form an acyclic graph, while lifecycle ownership follows direct construction: each module manages
only the DI modules it directly creates, never one it receives as a dependency. Each that starts or stops
something exposes its own `lifecycle: Lifecycle`. The entry-point unit's `RootModule` builds the roots and
lists their `lifecycle`s explicitly under the same ownership rule; there is no scanning. The DI rule has
the details.

### What goes in one file

- A file holds one type family: a sealed type with its variants, or a data class with the data classes
  nested in it. A class with behaviour always has its own file, even a private helper of one class. A model
  file holds the data class and nothing else: its rules and its factory are in `util` (`arch-domain.md`).
- A new data class that is a property type of exactly one class is nested in it. A type returned to another
  class is a top-level family in `model`.
- The state type of a screen or a menu (`CheckoutState`) is always its own file
  in `model/`: the view or the menu reads it, so it is returned to another class. It is never nested in the
  view model or state holder, and never a second declaration in that file.
- An `enum` used only through one type is nested in it; otherwise it is a top-level family of its own.
- Same file as the type: its companion object and, for a sealed type, its variants; nothing else. A file that
  declares a class holds no top-level function: a helper is a private member of the class, or an extension in
  `util/<Subject>Ext.kt` of the level that uses it, even when one file uses it (`KPlayer.toRatingPlayer()` of
  `RatingCommandExecutor`). Never a named class inside a function body, never an `inner class`. An anonymous
  `object :` inside a function only implements a type the project does not declare (a library's listener in a
  bridge, `no-callbacks.kt.md`). A Compose composable file declares no class, so an extension of a type the
  project does not declare that only it uses is `private` in it (`compose.kt.md`).
- A file of top-level functions is named after what they do (`DurationFormat.kt`, `TransferLimit.kt` for a
  rule over several types), never `Utils.kt`; helpers are never grouped in an `object` (a Compose `theme`
  object of shared values holds no function; Compose's two exceptions: the design-system theme object's
  `@Composable get()` of a `CompositionLocal`, and a design-system component's public `<Component>Defaults`,
  `compose.kt.md`).
- Multiplatform platform files carry the source-set suffix (`Platform.jvm.kt`).

### Tests

- `src/test/kotlin` mirrors `src/main/kotlin` package for package; `commonTest` mirrors `commonMain`, each
  platform test source set mirrors its main source set. A test file is named after the owner of the behaviour
  it checks (a use case, a repository implementation, a model rule, an entry point); a class with no behaviour
  of its own gets no test file.
- A `Fake…` scripts failures or records calls. A same-unit fake lives in the test tree in `fake/` inside the
  concept of the contract it replaces (`src/test/kotlin/…/data/dao/rating/fake/FakeRatingRepository.kt`). A double that only
  stores values in memory is not a fake but an in-memory implementation: production code in a `memory`
  technology package, usable by any unit's tests and by demos.
- A fake that tests of other units need lives in the `testFixtures` source set of the owning unit at the same
  path (`java-test-fixtures` for JVM units, `android { testFixtures { enable = true } }` for Android units),
  consumed with `testImplementation(testFixtures(projects.modules.jail.api))`. A Multiplatform unit has no
  `testFixtures`: its shared fakes go to `commonMain` of a sibling unit `<feature>/fake`, in
  `<unit root>/<concept>/fake/` (`payment/fake`: `offer/fake/FakePaymentApi.kt`). They are public and are
  consumed through a test source set's dependencies, never a production source set's. This is the exception
  to `fake` being confined to a test tree; the fake unit still depends on the `api` it fakes, not its `impl`.
- Three suites: in each sub-context's unit, model rules tested directly, use cases with fakes or in-memory
  implementations, technology packages against the real technology where it runs in a test (Exposed on an
  embedded database, a krate on a temporary directory); in the entry-point unit, integration tests of the
  wired application; architecture tests as their own suite.
