## Kotlin: package layout mechanics

The package-layout rule says which package a file goes to. This rule says how Kotlin and Gradle express it.

### Packages and directories

- The directory is the package: `src/main/kotlin/ru/astrainteractive/messagebridge/link/api/LinkApi.kt` declares
  `package ru.astrainteractive.messagebridge.link.api`.
- A unit's root package is the project's base package followed by the unit's path, with the container directory
  (`modules/`, `components/`) dropped and hyphens removed: `modules/link` → `ru.astrainteractive.messagebridge.link`,
  `feature/profile/impl` → `com.example.feature.profile.impl`. In an existing project, use the mapping the sibling
  units already use (`modules/jail` → `ru.astrainteractive.aspekt.module.jail` in AspeKt). An Android unit's
  `namespace` is its root package.
- `internal` is a legal package name; `ru.astrainteractive.messagebridge.link.internal` compiles and imports from
  Java as well.
- Platform code of a Kotlin Multiplatform unit goes to its source set (`androidMain`, `iosMain`, `jvmMain`) at the
  same package path, never to a package named after the platform. `expect` sits in `commonMain` in the kind that
  owns the concept; each `actual` sits at the same path in its source set, in a file with the platform suffix
  (`Clipboard.android.kt`).

### Visibility

Kotlin has no package-private visibility: `internal` means the build unit, and the unit's `test` source set sees
it. Write one of these on every top-level declaration:

| Declaration | Modifier |
|---|---|
| the entry point (`class NicknamePlugin : JavaPlugin()`) | `public` |
| the contents of an `api` unit; a DI module another unit constructs; a model in their signatures | `public` |
| every other top-level declaration | `internal` |
| a helper used only in its own file | `private` |
| a class member used only by its class | `private` |

```kotlin
// model/Nickname.kt in a plugin unit nothing depends on: the whole family is internal
internal data class Nickname(
    val owner: PlayerId,
    val text: String,
    val style: Style
) {
    internal data class Style(val color: NamedColor, val bold: Boolean)
}
```

Every unit the task creates enables the explicit API mode, so a missing modifier is a compile error:

```kotlin
kotlin {
    explicitApi()
}
```

An explicit-API error is fixed with the modifier the table gives for that declaration. In an existing unit the
task leaves the mode as it is and writes the modifiers from the table anyway.

### What goes in one file

A file holds one type family; the sealed type and its variants come first.

```kotlin
// model/LinkResponse.kt
public sealed interface LinkResponse {
    public data class Linked(val player: LinkedPlayer) : LinkResponse
    public data class AlreadyLinked(val existing: LinkedPlayer) : LinkResponse
    public data object CodeExpired : LinkResponse
}
```

- **Sealed hierarchies.** The sealed interface or class and all its variants are one file named after the
  parent, with the variants nested (`LinkResponse.Linked`). Direct subclasses of a sealed type must share its
  package and build unit anyway; one file is the shape that keeps them readable. A `when` over the variants in
  another file is normal use and never a reason to move a variant. The one different shape is an error hierarchy
  used as a `Result` payload: its subclasses are top-level in the same file, as the error-handling rule writes
  `OrderParseError : OrderError`, so a failure reads `Result.failure(OrderParseError(…))`.
- **Nested data classes.** A new data class that is a property type of exactly one class is nested in it:

  ```kotlin
  // model/Order.kt
  internal data class Order(
      val id: OrderId,
      val shipping: Shipping
  ) {
      internal data class Shipping(val address: String)
  }
  ```

  Other files may take `Order.Shipping` as a parameter or return it; that changes nothing. A data class that is a
  property of no class (a result, a summary, a response) or of two or more classes is top-level in its kind.
  Existing nesting is never undone.
- **Results.** A type a function returns to another class, sealed or data, is its own family in `model/`, never
  nested in the class that returns it:

  ```kotlin
  // model/RenameResult.kt, returned by usecase/RenameUseCase.kt
  internal sealed interface RenameResult {
      data class Renamed(val nickname: Nickname) : RenameResult
      data object NameTaken : RenameResult
  }
  ```
- **Enums** used only through one type are nested in it; otherwise an enum is a top-level family of its own.
- **Same file as the type:** its `companion object`, private helpers, and the extension functions every client of
  the type uses.
- **Never** a class inside a function body, and never an `inner class`: a helper that needs the outer instance is a
  private function of the outer class, or a class that receives the outer value as a constructor parameter.
- **Split** a file only above 400 lines, by moving a whole group (a group of variants, a group of extensions) into
  a second file of the same package named after the group.
- **Naming.** A file with one primary type is named after it. A file of top-level functions only is named after
  what they do (`DurationFormat.kt`), never `Utils.kt`.

### Tests

- `src/test/kotlin` mirrors `src/main/kotlin` package for package: `LinkApiImpl` in
  `…link.internal` is tested by `src/test/kotlin/…/link/internal/LinkApiImplTest.kt`. Kotlin Multiplatform:
  `commonTest` mirrors `commonMain`, each platform test source set mirrors its main source set.
- A hand-written fake lives in `fake/` inside the concept of the contract it replaces, in the test tree:
  `src/test/kotlin/…/link/player/fake/FakeLinkingDao.kt` fakes `…link.player.api.LinkingDao`.
- A fake that tests of other units need lives in the `testFixtures` source set of the unit that owns the contract,
  at the same path (`link/src/testFixtures/kotlin/…/link/player/fake/FakeLinkingDao.kt`), enabled with the
  `java-test-fixtures` plugin (JVM units) or `android { testFixtures { enable = true } }` (Android units); the
  consumer declares `testImplementation(testFixtures(projects.modules.link))`. A Kotlin Multiplatform unit has no
  `testFixtures`: its shared fakes go to a sibling unit `<feature>/fake` (root package `…<feature>.fake`, a leaf of
  fakes), which consumers add as a test dependency.
