## Kotlin Lambda Naming Rule

When writing Kotlin code, never use the implicit lambda parameter `it`.

Always give lambda parameters explicit, meaningful names.

### Bad

```kotlin
loadRequest().let {
    println("$it")
}
```

### Good

```kotlin
loadRequest().let { request ->
    println("$request")
}
```

Use names that describe the value.
