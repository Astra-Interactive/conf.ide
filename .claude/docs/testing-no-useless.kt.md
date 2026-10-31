# Testing Guidelines

Do not write tests that only verify language/framework behavior or trivial data storage.

Avoid tests like:

```kotlin
data class MyClass(val value: Int)

val clazz = MyClass(10)
assertEquals(10, clazz.value)
```

This only tests that Kotlin `data class` properties work.

Write tests only when they verify meaningful project behavior, such as:

* business logic
* validation rules
* edge cases
* error handling
* integration between components
* regressions for known bugs

Before adding a test, ask: **Would this test fail if our project logic were broken?**

If the answer is no, do not write the test.

The testing rule demands 100% line coverage and 100% branch coverage of new code that implements project
behaviour. Generated code and trivial field storage are outside this denominator, so they need no tests
that merely repeat language or framework behaviour. An uncovered line of that excluded code is not, by
itself, dead code.

An invariant check in a value object is project behaviour and needs valid and invalid input scenarios;
checking that a data class stored its constructor argument is not. The exclusion is by what the code does,
never by its package: `model`, `di` and UI may all contain behaviour that must be covered. Meaningful
integration tests can cover wiring and lifecycle ordering without a dedicated test file for each class.
If new project behaviour remains uncovered, add the missing scenario or establish that the code is dead;
do not classify it as trivial merely to reach the coverage target.
