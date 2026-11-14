## Kotlin: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Kotlin and Gradle express it.

### Packages and directories

- The directory is the package:
  `modules/data/dao/src/main/kotlin/com/example/plugin/data/dao/rating/api/RatingRepository.kt`
  declares `package com.example.plugin.data.dao.rating.api`.
- A unit's root package follows the project's existing convention, and a new unit takes the root package its
  neighbours would give it: one project keeps the container in the singular (`modules/jail` →
  `com.example.plugin.module.jail`), an app keeps the path after its container
  (`components/shop/payment/impl` → `com.example.shop.payment.impl`), another drops the platform suffix
  (`modules/event-bukkit` → `com.example.plugin.event`). A new project uses the base package followed by the
  unit path with hyphens removed and the container dropped. An Android unit's `namespace` is its root package.
- `api` is both a unit name (`gui/api`) and a kind package (`rating/api`).
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

- A published library unit switches explicit API mode on (`kotlin { explicitApi() }`) so that every public
  declaration there is deliberate. Application and plugin units never switch it on.
- A declaration one library unit needs from another, but no consumer of the library should use, is public and
  marked with an opt-in annotation (a `@RequiresOptIn` marker), never placed in a package named `internal`.

### Units and Gradle

- A unit's logical name equals its physical location; a container directory is never included as a project of
  its own. The root project holds no sources. Build logic lives in an included `build-logic` build with one
  convention plugin per unit type, applied only where needed, never through `subprojects`. Dependencies are
  declared with `implementation`; `api` only for a type exported through a Multiplatform framework.
- The build file of a plugin's `api` unit (`gui/api`) declares no platform dependency (no Paper, no Bukkit);
  the platform unit (`gui/bukkit`) depends on it (`arch-package.md`, Units 4).
- The types of a `<context>/contract` unit are `@Serializable` (`arch-package.md`, Units 1).

### Entry points, use cases and the platform

- The kinds of `arch-package.md`, Concepts and kinds 3 and 4, take their Kotlin words from the framework:
  `service` (a periodic task), `route` (a Ktor route), `composable` only with Compose, and the state holder by
  its class: `viewmodel` for an Android-style view model, `component` for a Decompose component; when a
  component holds a view model, each has its kind beside the other in the concept: `component` for the
  component (the state holder, with its interface when another unit opens it), `viewmodel` for the view model
  it holds (`offer/component/DefaultOfferComponent`, `offer/viewmodel/OfferViewModel`).
- A framework registration interface: `fun interface RouteRegistry { fun register(routing: Routing) }` may stay
  in `core/route` (`arch-package.md`, Contracts and implementations).
- In a plugin built on AstraLibs, a use case, and a `warmup` or `migration` in a platform-free unit, reach the
  server through AstraLibs' `PlatformServer` and its `server/*` abstractions (`server/player`,
  `server/location`, `server/permission`) or the sub-context's own contract.
- A state holder of a menu or screen (`component`, or `viewmodel` for a view model) holds no rule and calls use
  cases and contracts.

### DI modules

Which unit has a DI module, who owns each `lifecycle` and what `RootModule` lists: `di-manual.kt.md`.

### What goes in one file

The file rules are in `arch-package.md`, Files; Kotlin adds:

- The state type of a screen or a menu (`CheckoutState`) is its own file in `model/`: the view or the menu
  reads it, so it is returned to another class. It is never nested in the view model or state holder, and never
  a second declaration in that file.
- An `enum` created for one type is nested in it; otherwise it is a top-level family of its own.
- Same file as the type: its companion object and, for a sealed type, its variants; nothing else. Never a
  named class inside a function body, never an `inner class`. An anonymous `object :` inside a function only
  implements a type the project does not declare (a library's listener in a bridge, `no-callbacks.kt.md`).
- A file of top-level functions is named after what they do (`DurationFormat.kt`, `TransferLimit.kt` for a
  rule over several types), never `Utils.kt`.

### Tests

- `src/test/kotlin` mirrors `src/main/kotlin` package for package; `commonTest` mirrors `commonMain`, each
  platform test source set mirrors its main source set. A test file is named after the owner of the behaviour
  it checks (a use case, a repository implementation, a model rule, an entry point); a class with no behaviour
  of its own gets no test file.
- A `Fake…` scripts failures or records calls. A file of a `fake` package declares a `Fake…` class, and a double
  under another name is not written. A same-unit fake lives in the test tree in `fake/` inside the concept of the
  contract it replaces (`src/test/kotlin/…/data/dao/rating/fake/FakeRatingRepository.kt`). A double that only
  stores values in memory is not a fake but an in-memory implementation, `InMemory<Contract>` in a `memory`
  package of its concept: in production code when production code constructs it (a DI module, a demo instance),
  in the test tree at the same path when only the unit's own tests do, in `testFixtures` (KMP: `<feature>/fake`)
  when other units' tests do.
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
