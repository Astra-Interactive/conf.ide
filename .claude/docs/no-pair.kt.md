## No Anonymous Tuples

Do not use `Pair` or `Triple` for typed/domain data. `Pair` and `Triple` are never the type of a property, a
parameter, a return value or a type argument (`List<Pair<…>>`), written or inferred. `a to b` inside
`mapOf(…)` and destructuring a map entry stay.

Use a small named `data class` instead, with meaningful property names.

Example:

```kotlin
// Bad
List<Pair<String, Double>>

// Good
data class MuTypedTuple(val name: String, val value: Double)
List<MuTypedTuple>
```
