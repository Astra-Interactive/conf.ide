## Kotlin: No Console Output

When writing Kotlin code, never write to the console. `print`, `println`, `System.out`, `System.err`,
`Throwable.printStackTrace()` and `Thread.dumpStack()` are not called, in tests either.

Every message goes through the logger. A caught error is passed to the logger as its throwable argument,
which keeps the stack trace.

### Bad

```kotlin
result.onFailure { error ->
    println("Could not load order")
    error.printStackTrace()
}
```

### Good

```kotlin
result.onFailure { error -> logger.warn("Could not load order", error) }
```

The one exception is a command-line entry point whose product is the console output; it suppresses the
rule with the reason written next to it.
