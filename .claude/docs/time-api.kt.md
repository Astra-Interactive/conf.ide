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
