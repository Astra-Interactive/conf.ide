## Kotlin: domain building blocks

How the domain rule is written in Kotlin.

- An entity and a value object are immutable `data class`es; a state transition returns a copy.

  ```kotlin
  // jail/model/JailInmate.kt
  internal data class JailInmate(
      val id: PlayerId,
      val jail: JailId,
      val start: Instant,
      val duration: Duration
  ) {
      fun isSentenceOver(now: Instant): Boolean = now - start > duration
  }
  ```

- A typed identifier is a `@JvmInline value class` over the primitive (`value class PlayerId(val uuid: Uuid)`).
  A single-property value object is a value class too; one with an invariant checks it in `init` with
  `require` when a violation is a programmer error, or is built by a factory function returning `Result` when
  the input comes from a user.
- A sealed hierarchy is one file in `model`: the per-use-case results (`sealed interface RenameResult`), the
  error families of the error-handling rule, the events of an aggregate.
- A use case is `<Verb><Object>UseCase` in the `usecase` package of its concept, with `operator fun invoke`
  as its one public entry; it is constructed by its unit's DI module and takes its contracts through the
  constructor. It imports no platform type: the server is reached through AstraLibs' `server/*` abstractions or
  a contract of its sub-context.
- A repository is an `interface` named `<Aggregate>Repository` in the `api` package of the concept it stores
  (`data.dao.rating.api.RatingRepository`); its functions are `suspend` where they do I/O; implementations are
  `internal` classes in the technology unit or package, under the same concept
  (`data.exposed.rating.ExposedRatingRepository`).
- An aggregate factory with rules is a `companion object` function `create(...): Result<Aggregate>` in the
  aggregate's file.
- A domain event is a `data class` in `model`, published through the platform bus or a publisher contract in
  `api`; the Bukkit event type that carries it lives in the `event` kind of the platform unit.
- `@Serializable` on a model type is allowed; `org.jetbrains.exposed`, `org.bukkit`, `android.*` and the like
  are never imported in `model`, in a use case or in a contract. The architecture test checks the imports.
