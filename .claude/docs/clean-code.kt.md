## Kotlin: Clean Architecture

You are a senior software engineer. Your task is not only to make the code work, but to make it clean, maintainable, readable, extensible, and production-ready.

Follow the principles from **Clean Code by Robert C. Martin** and apply appropriate **software design patterns** where they improve the solution.

Core requirements. A checker checks what a rule states as a fixed name, number or shape; everything else in
these rules is the reviewer's call.

### 1. Write clean, readable code

* Use meaningful names for variables, functions, classes, files, and modules.
* Avoid vague names like `data`, `temp`, `foo`, `manager`, `handler`, unless the meaning is obvious (the
  reviewer's call).
* A function is named with a verb that says what happens; one that returns a value is never a bare noun
  (`cardSegments()`, `featureShortcuts()`, `titleStyle()` mislead) and never starts with `get`, except
  `getState()` where a project already uses it as the view model's state accessor. `operator fun invoke`, a DI
  `provide…`, an override of a framework signature, an overload of a library function that only changes a
  parameter's type (`tween(duration: Duration, …)` beside Compose's `tween(durationMillis)`) and a function of
  a design-system `<Component>Defaults`, named as Google's Compose API guidelines and Material name it
  (`GlassButtonDefaults.colors()`, as `ButtonDefaults.buttonColors()`), keep their names. A `@Composable` that
  emits UI and returns `Unit` is named for what it shows, in PascalCase, ending in `Composable`
  (`OrderSummaryComposable`, a screen `<Feature>ScreenComposable`, `compose.kt.md`), except a function of the
  preview block (`…Preview`, `OrderSummaryPreviewSheet`), the theme function (`AppTheme`) and a component's
  `Render()`; a `Modifier` extension is named like Compose's modifiers (`padding`, `background`); a test is
  named by the testing rule. The usual verbs; another verb is fine when it says what happens as plainly:

  | Verb | When | Example |
  |---|---|---|
  | `select` | one of fixed values, chosen by a condition | `selectCardSegments(stage)` |
  | `resolve` | a value from several sources or by precedence, a `@Composable` reading the theme included | `resolveTitleStyle(size)` |
  | `build` | a new object or list assembled from parts | `buildShortcuts()` |
  | `create` | an aggregate factory with a rule, returning `Result` | `createJail(name, location)` |
  | `compute` | a number or geometry | `computeOpacity(distance)` |
  | `format` | a value turned into text for display | `formatPrice(plan)` |
  | `parse` | text turned into a value, returning `Result` | `parseOrder(raw)` |
  | `find` | a lookup that may return `null` | `findPlan(id)` |
  | `load` / `fetch` | a read from storage / from the network | `loadOffer()`, `fetchExchangeRate()` |
  | `save` / `send` / `notify` | a write, a dispatch | `notifyPurchaseFailed()` |
  | `is` / `has` / `can` / `should` | a `Boolean` predicate | `isSentenceOver(now)`, `canRead(user)` |
  | `to<Type>` | a conversion that copies; an extension | `Plan.toPlanContent()` |
  | `as<Type>` | a view over the same object, no copy; a Compose resource read as what it shows | `asStateFlow()`, `asPainter()` |
  | `remember<Thing>` | a `@Composable` that calls `remember` | `rememberAppearProgress(...)` |
  | `on<Event>` | a view-model handler of a user action, one per action; one `onAction(action)` where the project already dispatches so | `onPurchase()` |
  | `update<Thing>` | a state transition | `updateContent { }` |

  Never `map` in a name (`toContent`, not `mapToContent`: `map` is the word of collections), never
  `make`, `do`, `handle` or `process`. A function with no arguments that only returns a stored value is a
  `val`. A banned verb is the first camelCase word of a function name (`getUser`, `mapToContent`, `handleClick`,
  `doWork`); the same letters later in the name are not banned. `getState()` is allowed only in a view model of
  a project whose view models already declare it. A checker enforces only these bans; whether another verb says
  what happens as plainly is the reviewer's call.
* Keep functions small and focused.
* Each function should do one thing.
* Avoid deeply nested logic. "Small" and "deeply nested" are the project's detekt `LongMethod` and
  `NestedBlockDepth` thresholds (60 lines and 4 levels when the project sets none).
* Prefer early returns and guard clauses. An `if` whose whole body is one `return` (a labelled one included)
  is one line without braces when it fits the project's detekt `MaxLineLength` (120 when none is set):
  `if (!isVisible) return@LaunchedEffect`.
* Avoid duplicated code.
* Before writing a helper, look for one that exists in the project or in a library the project already
  depends on, and use it: an extension the project has over `stringResource(…)`, mikro's
  `Result.propagateCancellationException()`. A helper that duplicates one that exists is dead weight.
* New code has no dead code, unused variables or unnecessary comments; in an old file they are removed only in
  a refactoring the user asked for, never by a task that plugs new code in.
* No `Helper`, `Util` or `Manager` classes: a class with behaviour has a role, and the role names it and its package.
* A file holds one type family: a sealed hierarchy with all its variants, a data class with the data classes nested in it. The Kotlin package-layout rule says what goes in one file.

### 2. Follow SOLID principles

* Single Responsibility Principle: each class/module should have one clear reason to change.
* Open/Closed Principle: code should be extendable without modifying existing logic too much.
* Liskov Substitution Principle: subclasses should be safely replaceable by their parent type.
* Interface Segregation Principle: avoid large interfaces with unrelated methods.
* Dependency Inversion Principle: depend on abstractions, not concrete implementations. An interface exists on the four triggers of the package-layout rule: another unit calls it, two or more implementations exist or one is known to come, an inner part declares what it needs from an outer one, or a test must replace a contract over I/O or the platform with a fake.

### 3. Use design patterns when appropriate

Use design patterns only when they make the code simpler, cleaner, or easier to extend. Do not over-engineer.

Consider patterns such as:

* Strategy Pattern for interchangeable algorithms or behaviors.
* Factory Pattern only as the domain rule allows it: a function that creates an aggregate under a rule, or a nested `fun interface Factory` for an object that needs arguments known only when it is created; dependencies are constructed at the composition root.
* Builder Pattern for constructing complex objects step by step.
* Observer/Event Pattern for event-driven systems.
* Repository Pattern for data access abstraction.
* Adapter Pattern for integrating external APIs or incompatible interfaces.
* Decorator Pattern for adding behavior without modifying existing classes.
* Command Pattern for actions, tasks, undo/redo, or queued operations.
* Dependency Injection for testability and decoupling.

Before using a pattern, briefly explain why it fits the problem.

### 4. Separate responsibilities

Keep each responsibility in its own class and each class in the kind package of its concept: contracts in `api/`, data in `model/`, operations in `usecase/`, extensions in `util/`, wiring in `di/`, implementations where the package-layout rule places them. The package-layout rule and skill decide the packages and when a sub-context gets its own build unit.

Do not mix unrelated responsibilities in one class or function.

### 5. Make the code testable

* Avoid hard-coded dependencies.
* Inject dependencies where possible.
* Keep pure logic separate from I/O.
* Make functions deterministic when practical.
* Cover new code with tests as the testing rule says.
* Cover important edge cases.

### 6. Handle errors properly

* Do not ignore errors.
* Use clear error messages.
* Validate inputs.
* Fail fast when invalid state is detected.
* Avoid swallowing exceptions silently.

### 7. Prefer clarity over cleverness

* Do not write overly complex one-liners.
* An expression body (`fun f() = …`) only when the signature and the body are one line: `=` never ends a
  line, `= when {`, `= transaction {` and the like are block bodies, and a signature that wraps takes a block
  body. A body that would wrap after `=` is a block body with an explicit `return`.

  ```kotlin
  // Bad
  internal fun Modifier.cardCanvas(): Modifier =
      canvasAnchoredToCard(CARD_TOP_IN_CARD_ART)

  // Good
  internal fun Modifier.cardCanvas(): Modifier = canvasAnchoredToCard(CARD_TOP_IN_CARD_ART)
  ```

* A lambda whose whole body is one `if` without `else` around two or more statements is a guard with a
  labelled return, in `pointerInput`, `LaunchedEffect`, `launch`, `forEach` alike. An `if` around one
  statement stays as it is: the guard would only add lines.

  ```kotlin
  // Bad
  LaunchedEffect(isVisible) {
      if (isVisible) {
          delay(AutoHideDelay)
          onHide.invoke()
      }
  }

  // Good
  LaunchedEffect(isVisible) {
      if (!isVisible) return@LaunchedEffect
      delay(AutoHideDelay)
      onHide.invoke()
  }
  ```

* One arithmetic operator (`+`, `-`, `*`, `/`, `%`) directly before a trailing call (`.sp`, `.dp`,
  `.toInt()`, `.coerceIn(…)`) is written as its named function (`plus`, `minus`, `times`, `div`, `rem`), so
  the chain reads left to right without parentheses. Two or more operators before a trailing call: a named
  `val` first, then the call; `a.times(b).plus(c)` is never written. An expression with no trailing call
  keeps its operators (`subtotal * (1 + taxRate)`).

  ```kotlin
  // Bad
  lineHeight.isEm -> (fontSize.value * lineHeight.value).sp

  // Good
  lineHeight.isEm -> fontSize.value.times(lineHeight.value).sp
  ```

* A condition that does not fit on one line is never wrapped at `&&` or `||`. Split it, in this order:
  1. a guard clause (`if (current !is CheckoutState.Content) return current`) for a clause that a later
     one depends on through a smart cast or a null check, and for a clause that is costly;
  2. a named `val` per remaining clause, named for what it means, so that the condition itself reads as a
     sentence;
  3. only when the named values still do not fit on one line, a chain joined with `.and(…)` and `.or(…)`, one
     step per line. The chain evaluates both sides, so it holds only values that are already named or single
     calls.

  ```kotlin
  // Bad
  if (current is CheckoutState.Content && current.stage == CheckoutStage.PAYMENT &&
      !current.isBusy && current.cart.expiresAt > now
  ) {
      current.copy(isBusy = true)
  } else {
      current
  }

  // Good
  if (current !is CheckoutState.Content) return current
  val isPaymentStage = current.stage == CheckoutStage.PAYMENT
  val isIdle = !current.isBusy
  val isCartAlive = current.cart.expiresAt > now
  if (isPaymentStage && isIdle && isCartAlive) return current.copy(isBusy = true)
  return current
  ```

* A call with three or more arguments puts each argument on its own line, whether or not it would fit; one or
  two arguments stay on one line when they fit the project's detekt `MaxLineLength` (120 when none is set).
  The column limit decides nothing else here. A trailing lambda
  counts as an argument: `remember(icon, label) { … }` has three, so `icon` and `label` go on their own lines
  and the lambda follows the closing parenthesis.

  ```kotlin
  // Bad
  current.copy(stage = CheckoutStage.SUCCESS, isBusy = false, expiresAt = result.expiresAt)

  // Good
  current.copy(
      stage = CheckoutStage.SUCCESS,
      isBusy = false,
      expiresAt = result.expiresAt
  )
  ```

* A call on a property or a parameter is written with `.invoke()`, so the reader sees a value being called,
  not a declared function: a lambda, a `Provider`, a `Factory`, a use case with `operator fun invoke`.

  ```kotlin
  // Bad
  val viewModel = splashViewModelProvider()
  val result = ratePlayerUseCase(player)

  // Good
  val viewModel = splashViewModelProvider.invoke()
  val result = ratePlayerUseCase.invoke(player)
  ```

* Do not use advanced language features unless they improve readability.
* Code should be understandable by another developer without needing a long explanation.

### 8. Comments and documentation

* Do not comment obvious code.
* Use comments only to explain “why”, not “what”.
* The public API of a published library is documented by the KDoc rule; application code carries no KDoc beyond the KDoc rule's two exceptions.

### 9. Refactor before final answer

Before providing the final code, review it and improve:

* Naming
* Duplication
* Function size
* Class responsibilities
* Coupling
* Testability
* Error handling
* Pattern usage
* File and package organization: answer the package-layout skill's checklist

### Important:

Do not produce quick-and-dirty code unless explicitly asked. Treat every coding task as production-quality software design. Production quality includes the right amount of structure: the packages, layers, interfaces and build units the package-layout rules call for, and no more.
