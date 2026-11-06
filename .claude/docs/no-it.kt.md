## Kotlin Lambda Naming Rule

When writing Kotlin code, never use the implicit lambda parameter `it`.

Always give lambda parameters explicit, meaningful names.

### Bad

```kotlin
loadRequest().let {
    logger.info("Loaded $it")
}
```

### Good

```kotlin
loadRequest().let { request ->
    logger.info("Loaded $request")
}
```

Use names that describe the value.
