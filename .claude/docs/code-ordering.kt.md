## Code ordering rules

When writing or modifying code, order declarations by dependency, not by call-site convenience.

### Layout of a file or scope

1. `val` / `var` declarations, configuration, and shared state come first, before any function. A secondary
   constructor follows them, before the functions.
2. Functions follow, ordered so that a callee is declared above its caller:
   - if function `A` calls function `B`, `B` appears before `A`;
   - private helpers sit above the functions that use them;
   - lower-level utilities come before higher-level orchestration functions.
3. `init` blocks follow the last function; only nested types and the `companion object` come after them.
   Every property sits above the functions (rule 1), so it is initialized before any `init` block runs.
4. Never append private helpers after the public functions that depend on them.
5. Preserve this ordering when refactoring existing code.

```kotlin
class CartViewModel(
    private val cartRepository: CartRepository
) : ViewModel() {
    private val state = MutableStateFlow<CartState>(CartState.Loading)

    private suspend fun loadCart() {
        state.value = cartRepository.loadCart()
    }

    init {
        viewModelScope.launch { loadCart() }
    }
}
```

### Exception: `companion object` is always last

Inside a class the `companion object` is the last declaration, and class-level constants (`const val`,
shared defaults, keys, limits) live there. Rule 1 covers instance properties and top-level properties
only; it does not pull constants to the top of the class.

This holds for a DI module and for an `interface` too: both keep their constants in a `companion object`. A
`private object` beside a type that only holds that type's constants is forbidden.

```kotlin
// Bad
private object FeatureFlagModuleDefaults {
    val ReloadInterval = 1.minutes
}

internal class FeatureFlagModule(coreModule: CoreModule) {
    val featureFlagReloader = IntervalFeatureFlagReloader(FeatureFlagModuleDefaults.ReloadInterval, coreModule.ioScope)
}

// Good
internal class FeatureFlagModule(coreModule: CoreModule) {
    val featureFlagReloader = IntervalFeatureFlagReloader(RELOAD_INTERVAL, coreModule.ioScope)

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

    fun computePrice(order: Order): Money {
        if (order.items.size > MAX_ITEMS) return Money.ZERO
        return priceCache.getOrPut(order.id) { applyTax(order.subtotal) }
    }

    companion object {
        private const val MAX_ITEMS = 100
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
    private val columns: List<Column> = filterVisibleColumns()

    private fun filterVisibleColumns(): List<Column> = source.schema.columns.filter(Column::visible)
}
```
