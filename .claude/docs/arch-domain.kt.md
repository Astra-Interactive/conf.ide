## Kotlin: domain building blocks

How the domain rule is written in Kotlin.

- An entity and a value object are immutable `data class`es (a single-property value object a `value class`)
  holding what the domain rule lists, no function. A type with an invariant checks it in an `init` block of
  `require` calls and nothing else; `init` runs for the constructor, for `copy()` and for a `@Serializable`
  type's decoder. It is the backstop: a rule that can fail checks first and returns the failure. Input from a
  user goes through `parse<Type>(raw): Result<Type>` in `util`; a file or a payload is decoded inside the
  `runCatching` that `error-handling.kt.md` allows around serialization, which maps the failure, an
  `IllegalArgumentException`, to the domain error.

  ```kotlin
  // jail/model/JailInmate.kt
  internal data class JailInmate(
      val id: PlayerId,
      val jail: JailId,
      val start: Instant,
      val duration: Duration
  )

  // jail/util/JailInmateExt.kt
  internal fun JailInmate.isSentenceOver(now: Instant): Boolean = now - start > duration
  ```

- A typed identifier is a `@JvmInline value class` over the primitive (`value class PlayerId(val uuid: Uuid)`).
- A sealed hierarchy (`sealed interface RenameResult`) is one file in `model` (`arch-package.md`, Files): a
  per-use-case result, an error family, the events of an aggregate.
- A use case's one public entry is `operator fun invoke`; its unit's DI module constructs it, and it takes its
  contracts through the constructor. It imports no platform type, so the server is reached through a contract
  (`arch-package.md`, Contracts and implementations); in a plugin built on AstraLibs, through its `server/*`
  abstractions or a contract of its sub-context.
- A repository's functions are `suspend` where they do I/O; its implementations are `internal` classes in the
  technology unit or package, under the same concept (`data.exposed.rating.ExposedRatingRepository`); which
  are public: `arch-package.kt.md`, Visibility.
- A domain event is a `data class`.
- `@Serializable` on a model type is allowed. The imports that count as platform or framework types are the
  linter's built-in framework list (`org.jetbrains.exposed`, `org.bukkit`, `android.*` among them) and the
  project's `technologyWords`; `model`, a use case and a domain contract import none. The exceptions
  (`arch-package.md`, Contracts and implementations): a framework registration interface, and a state
  holder's interface, which may import its UI framework (Decompose's `ComponentContext`, `Value`). In `model`: Compose types in a UI unit
  (`androidx.compose.*`, `org.jetbrains.compose.*`; `compose.kt.md`) and a framework's exception subclasses in
  its entry-point unit (`arch-domain.md`, What the model may import).
