## Kotlin Timestamp and Duration Rule

When writing Kotlin code, do not represent dates, timestamps, or durations as raw primitive or text types.

Avoid using:

```kotlin
Long
Int
String
```

for datetime-related values.

### Bad

```kotlin
val createdAt: Long
val expiresAt: String
val timeoutSeconds: Int
```

### Good

```kotlin
import kotlin.time.Duration
import kotlin.time.Instant

val createdAt: Instant
val expiresAt: Instant
val timeout: Duration
```

Use `kotlin.time.Instant` for exact moments in time. Never `kotlinx.datetime.Instant`: all projects are on Kotlin 2.1.20+.

Use `kotlin.time.Duration` for time intervals, delays, cooldowns, timeouts, and expiration lengths.

Only convert timestamps or durations to `Long`, `Int`, or `String` at external boundaries, such as database storage, JSON serialization, logging, or API compatibility layers. A framework call that takes only milliseconds (`tween(durationMillis = …)`) is such a boundary: the constant stays a `Duration` (`val CardIn = 400.milliseconds`, never `CARD_IN_MS = 400`), and `.inWholeMilliseconds.toInt()` is written at that call; a literal at the call (`tween(durationMillis = 400)`) is already at the boundary. A call with a `Duration` overload (`delay(duration)`) takes the `Duration` directly.

### Java time types and the system clock

- `java.util.Date` and `kotlinx.datetime.Clock` are never imported: use `kotlin.time.Instant` and
  `kotlin.time.Clock`.
- `java.time.Instant`, `java.time.Duration`, `java.time.LocalDateTime` and `java.util.Calendar` are imported
  only in a technology package or unit (`exposed`, `room`, `ktor`, `krate`, `sqldelight`, `datastore`,
  `retrofit`, `okhttp`, `table`, `entity`) or in a `contract` unit, where a library or the wire format demands
  them, and are converted to `kotlin.time` there.
- The current moment comes from `kotlin.time.Clock` (`Clock.System.now()`), and an elapsed time from
  `kotlin.time.TimeSource.Monotonic`; `System.currentTimeMillis()` and `System.nanoTime()` are never called. A
  class that must be testable takes the `Clock` through its constructor, built in the DI module
  (`di-manual-constructors.kt.md`).
