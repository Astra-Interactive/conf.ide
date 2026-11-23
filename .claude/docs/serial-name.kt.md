## Serial Names Rule

Every serialized property of a `@Serializable` class carries `@SerialName`, so the wire name does not
change when the Kotlin property is renamed.

The rule reads the serialized properties: the `val` and `var` parameters of the primary constructor and the
properties declared in the class body.

Bad:

```kotlin
@Serializable
data class PlayerDto(
    val uuid: String,
    val name: String
)
```

Good:

```kotlin
@Serializable
data class PlayerDto(
    @SerialName("uuid") val uuid: String,
    @SerialName("name") val name: String
)
```

A `@Transient` property is not serialized, so it needs no `@SerialName`:

```kotlin
@Serializable
data class PlayerDto(
    @SerialName("uuid") val uuid: String,
    @Transient val cachedName: String = ""
)
```

Enum entries are named by their Kotlin name and cannot carry `@SerialName`; the rule does not report them.
