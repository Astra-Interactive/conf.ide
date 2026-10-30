## Constructors Dependency Injection Rule

Never instantiate concrete dependencies inside class constructors, constructor default parameters, fields, or methods.

A dependency is an object with behaviour the class calls and a test might replace (a repository, a client, a
clock). The class's own state (`MutableStateFlow`, `Channel`, a map) is not one.

Dependencies must be created only at the composition root / DI module / application wiring layer, then passed down from parent to child.

Bad:

```kotlin
class LivePredictor(
    private val repo: MarketDataRepository,
    private val pipeline: FeatureLabelPipeline = FeatureLabelPipeline(),
    private val model: DirectionModel = TemperatureCalibratedDirectionModel(),
    private val clock: Clock = Clock.System
)
```

Good:

```kotlin
class LivePredictor(
    private val repo: MarketDataRepository,
    private val pipeline: FeatureLabelPipeline,
    private val model: DirectionModel,
    private val clock: Clock
)
```

When adding a new dependency, update the root wiring instead of adding `= SomeImplementation()` in the class.

A value derived from the class's own lifecycle, such as a scope built on `viewModelScope`
(`viewModelScope.asSingleJobScope()`), is not a dependency: it is part of the class and stays a field.
