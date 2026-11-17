## No Anonymous Tuples

Do not use `Pair` or `Triple` for typed/domain data. `Pair` and `Triple` are never the type of a property, a
parameter, a return value or a type argument (`List<Pair<…>>`), written or inferred. `a to b` inside
`mapOf(…)` and destructuring a map entry stay. So does a tuple passed straight to a parameter that a library
declares as `Pair` or `Triple` (`PanelsLayout(weights = 0.4F to 0.6F)`): the project declares nothing there and
has no other way to call it. A parameter the project declares, or a library parameter of a generic type (`T`)
inferred as `Pair`, is not such a case.

Use a small named `data class` instead, with meaningful property names.

The restriction concerns Kotlin's actual `Pair` and `Triple` types. An unrelated type named `Pair`,
or an overloaded `to` DSL function returning `Unit`, is not a tuple. Resolve symbols and types before
reporting; an unresolved call alone is not evidence of a tuple.

Example:

```kotlin
// Bad
List<Pair<String, Double>>

// Good
data class MuTypedTuple(val name: String, val value: Double)
List<MuTypedTuple>
```
