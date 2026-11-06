## Kotlin Lambda Naming Rule

When writing Kotlin code, never use the implicit lambda parameter `it`, and never name anything `it`:
not a lambda parameter, not a function or constructor parameter (`fun fromDTO(it: WordDTO)`), not a
destructured entry.

Always give lambda and function parameters explicit, meaningful names.

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
