## No Nested Classes Rule

Do not declare classes inside other classes.

All domain models, DTOs, services, helpers, factories, and implementations must be top-level declarations.

Bad — nested non-sealed class:

```kotlin
// PredictionModel.kt
class PredictionModel {
    data class Config(
        val threshold: Double
    )
}
```

Good — separate top-level classes in separate files:

```kotlin
// PredictionModelConfig.kt
data class PredictionModelConfig(
    val threshold: Double
)
```

```kotlin
// PredictionModel.kt
class PredictionModel
```

```kotlin
// PredictionModelTrainer.kt
class PredictionModelTrainer
```

Kotlin `inner class` is strictly forbidden.

Bad:

```kotlin
// PredictionModel.kt
class PredictionModel {
    inner class Trainer
}
```

### Exceptions

- `companion object` is always nested; it cannot exist outside a class.
- Sealed hierarchies: variants of a `sealed interface` / `sealed class` may be nested in the parent or declared top-level in the parent's file.
- `data class`: child data classes may be nested inside the parent data class, so they share one file.
- `enum class` and `object` are top-level. Rare exception: an `enum class` used only inside one class may stay nested in that class.

Allowed — one file:

```kotlin
// PredictionResult.kt
sealed interface PredictionResult {
    data class Success(val value: Double) : PredictionResult
    data class Failed(val reason: String) : PredictionResult
}
```

Allowed — one file:

```kotlin
// PredictionResult.kt
sealed interface PredictionResult

data class SuccessPredictionResult(
    val value: Double
) : PredictionResult

data class FailedPredictionResult(
    val reason: String
) : PredictionResult
```

Allowed — one file:

```kotlin
// Order.kt
data class Order(
    val id: OrderId,
    val shipping: Shipping
) {
    data class Shipping(
        val address: String
    )
}
```

Do not use nested classes for grouping. Only the exceptions above may be nested or kept together in one file.
