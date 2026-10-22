## Code ordering rules

When writing or modifying code, order declarations by dependency, not by call-site convenience.

### Layout of a file or scope

1. `val` / `var` declarations, configuration, and shared state come first, before any function.
2. Functions follow, ordered so that a callee is declared above its caller:
   - if function `A` calls function `B`, `B` appears before `A`;
   - private helpers sit above the functions that use them;
   - lower-level utilities come before higher-level orchestration functions.
3. Never append private helpers after the public functions that depend on them.
4. Preserve this ordering when refactoring existing code.

### Exception: `companion object` is always last

Inside a class the `companion object` is the last declaration, and class-level constants (`const val`,
shared defaults, keys, limits) live there. Rule 1 covers instance properties and top-level properties
only; it does not pull constants to the top of the class.

This holds for an `interface` too: an interface has a `companion object`, and a DI module declared as one
keeps its constants there. A `private object` beside a type that only holds that type's constants is
forbidden.

```kotlin
// Bad
private object PostHogFeatureFlagDefaults {
    val ReloadInterval = 1.minutes
}

@ContributesTo(AppGraph::class)
interface PostHogFeatureFlagModule {
    @Provides
    fun provideFeatureFlagReloader(scope: CoroutineScope): FeatureFlagReloader {
        return PostHogFeatureFlagReloader(interval = PostHogFeatureFlagDefaults.ReloadInterval, scope = scope)
    }
}

// Good
@ContributesTo(AppGraph::class)
interface PostHogFeatureFlagModule {
    @Provides
    fun provideFeatureFlagReloader(scope: CoroutineScope): FeatureFlagReloader {
        return PostHogFeatureFlagReloader(interval = RELOAD_INTERVAL, scope = scope)
    }

    companion object {
        private val RELOAD_INTERVAL = 1.minutes
    }
}
```

```kotlin
class OrderPricing(
    private val taxRate: Double
) {
    private val priceCache = mutableMapOf<OrderId, Money>()

    private fun applyTax(subtotal: Money): Money = subtotal * (1 + taxRate)

    fun priceOf(order: Order): Money {
        if (order.items.size > MAX_ITEMS) {
            return Money.ZERO
        }
        return priceCache.getOrPut(order.id) { applyTax(order.subtotal) }
    }

    companion object {
        const val MAX_ITEMS = 100
    }
}
```

### Exception: the preview block of a composable file

Previews close a composable file, and everything that only previews use (constants, fixtures, helper
composables) sits in that block, before the first function that uses it, never at the top of the file. The
Compose rule (`compose.kt.md`) gives the shape.

### Exception: property initializers

A property whose initializer calls a function stays at the top with the other properties. Rule 1 wins
over rule 2 here, so this is the one place where a callee is declared below its caller.

```kotlin
class ReportBuilder(
    private val source: ReportSource
) {
    private val columns: List<Column> = resolveColumns()

    private fun resolveColumns(): List<Column> = source.schema.columns.filter { column -> column.visible }
}
```
