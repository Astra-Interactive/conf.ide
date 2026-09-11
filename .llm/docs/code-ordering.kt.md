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

```kotlin
class OrderPricing(
    private val taxRate: Double
) {
    private val priceCache = mutableMapOf<OrderId, Money>()

    private fun applyTax(subtotal: Money): Money = subtotal * (1 + taxRate)

    fun priceOf(order: Order): Money {
        if (order.items.size > MAX_ITEMS) {
            return Money.zero()
        }
        return priceCache.getOrPut(order.id) { applyTax(order.subtotal) }
    }

    companion object {
        const val MAX_ITEMS = 100
    }
}
```

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
