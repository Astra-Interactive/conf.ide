## Kotlin: Compose screens

How a UI unit built on Compose is laid out and written. The package-layout rule gives the shape
(`<concept>/<kind>/<File>`); the `compose-hoisting` skill gives state hoisting, `Render()` and previews; this
rule fills what is specific to Compose. The verb table of `clean-code.kt.md` and the flow rules of
`coroutines.kt.md` apply unchanged. A UI unit is one whose build already depends on Compose: the `impl` unit
of a screen feature, the design-system unit (`core/ui` in BUSY: a unit path, which may keep its word, not a
package created inside a unit).

### Packages of a UI unit

- A type that exists only to feed `@Composable` functions lives in the ordinary `model` of its level, next to
  `composable/`, even when it carries Compose types (`Painter`, `Dp`, `Color`, `Easing`, `TextStyle`). There
  is no `composable/model`: a kind package holds only files. In a UI unit, `model` may import
  `androidx.compose.*` and `org.jetbrains.compose.*`; the ban on ORM, platform and network imports in `model`
  stays, and a UI type is never a copy of a domain type with the same fields.

  ```
  impl/model/BenefitContent.kt                 data class BenefitContent(val painter: Painter, val label: String)
  impl/splash/model/SplashPaywallState.kt      the screen state, its own file
  impl/composable/BenefitComposable.kt         the function that reads it
  ```

  The input of a composable is `<Thing>Content`; the state of a screen is `<Screen>State`.
- A composable file declares no class: it holds `@Composable` functions, their constants and the preview
  block; the one declaration beside them is the public `<Component>Defaults` object of a design-system
  component, in that component's file (Material's shape: `ButtonDefaults` in `Button.kt`). An extension that
  only this file uses, a `@Composable` one or one returning a Compose type (`Modifier`, `Brush`,
  `TextStyle`) included, is `private` in this file; one that several files use is `util/<Subject>Ext.kt` of
  the level, like any extension. There is no `composable/util`. The pure rules of a domain type stay in the
  `util` of its `api` unit, where Compose is not on the classpath.
- The file rule has no exception for `private` types of a composable file. A `data class` goes to `model`
  with fields only, its formulas to `util/<Type>Ext.kt`; an `enum` used only through one model type is nested
  in it, otherwise it is its own file.

  ```
  // Bad: ScrollFadeComposable.kt holds FadeSide, SoftEdge with opacityAt(), ScrollFadeDefaults and six previews
  // Good
  impl/model/SoftEdge.kt                     data class SoftEdge(val edge: Float, val sigma: Float, ...)
  impl/model/FadeSide.kt                     enum class FadeSide { TOP, BOTTOM }
  impl/util/SoftEdgeExt.kt                   fun SoftEdge.computeOpacity(distance: Float): Float
  impl/composable/ScrollFadeComposable.kt    @Composable functions, private vals, previews
  ```

- Values that several composables of one level must share (the timings and easings of one screen's
  animation, the spacing of one feature) live in the kind `theme` of that level, as an `internal object`
  named for what it is: `impl/theme/PaywallMotion.kt`. At a feature level the object holds values only, no
  function, so it is not a namespace of helpers. Values of the whole application live only in the
  design-system unit, whose `theme` also holds the theme itself: the `CompositionLocal`s and the
  `@Composable` theme function. Not `composable` (it holds functions), not `model`, not `util`. A value one
  file uses stays private in that file.

### Constants of a composable

- The constants of one composable are top-level `private val` / `private const val` at the top of its file
  (code-ordering rule 1). No `private object XxxDefaults`: top-level vals give the same grouping without a
  second declaration, and an `object` of values beside functions is a namespace. A `<Component>Defaults`
  object exists only as the public API of a reusable design-system component, where it is part of the
  signature (`colors: ButtonColors = ButtonDefaults.colors()`).

  ```kotlin
  // Bad
  private object AuthOtpScreenDefaults {
      val NavBarTopGap = 14.dp
  }

  // Good
  private val NavBarTopGap = 14.dp
  ```

- Case, in composable and `theme` files: `const val` primitives and strings are `UPPER_SNAKE`; `val` objects
  (`Dp`, `Color`, `Easing`, a model instance, a preview list) are `PascalCase`. Elsewhere the Kotlin
  convention stays.

  ```kotlin
  private const val PREVIEW_ROW_COUNT = 20
  private val PreviewCanvasColor = Color(0xFF1F1F1F)
  private val CardTopSpacing = 64.dp
  ```

- A constant value is a `val`, not a function: it is allocated once for the process, a function allocates
  per call. A function only when the value depends on an argument or on composition.
- A number under a named argument that explains it, used once, stays inline: `tween(durationMillis = 400)`.
  Extract when two uses must change together, or when several values form one spec tuned together (the
  timings of one animation): private vals of the file when one file uses them, `theme` when several do.
  Equal literals near each other are not one constant: the same `400` twice may be a coincidence.

### Previews

Previews close the file (the `compose-hoisting` skill). Everything that only previews use, constants,
fixtures (`PreviewPlans`), helper composables, sits in that block, before the first function that uses it,
never at the top of the file. Preview constants start with `PREVIEW_`, preview vals with `Preview`, and every
function of the block carries `Preview` in its name (`<Composable><Scenario>Preview` for a `@Preview`, as the
skill says; `HeroCopyPreviewSheet` for a helper). This is an exception to rule 1 of the code-ordering rule.

```kotlin
@Composable
internal fun HeroCopyComposable(...) { ... }

private const val PREVIEW_TITLE = "Unlock more control."

@Composable
private fun HeroCopyPreviewSheet(align: HeroCopyAlign) { ... }

@Preview
@Composable
private fun HeroCopyCenterPreview() { ... }
```

### Naming

- `remember` in a name means `remember` in the body. A `@Composable` that builds a list of content on every
  composition is not `rememberX`; it remembers the list, and then the prefix is earned.

  ```kotlin
  // Bad: builds the list on every recomposition under a name that promises remember
  @Composable
  private fun rememberFeatureShortcuts(): ImmutableList<FeatureShortcutContent> = persistentListOf(...)

  // Good
  @Composable
  private fun rememberFeatureShortcuts(): ImmutableList<FeatureShortcutContent> {
      val timerIcon = IconsRes.drawable.ic_bi_timer_fill.asPainter()
      val timerLabel = StringsRes.string.paywall_feature_timer_settings.asComposableString()
      return remember(timerIcon, timerLabel) { persistentListOf(FeatureShortcutContent(timerIcon, timerLabel)) }
  }
  ```

- A value-returning `@Composable` without `remember` takes a verb from the table in `clean-code.kt.md`:
  `resolveTitleStyle(size)` for a read of the theme, `selectCardSegments(stage)` for a choice among fixed
  values, never a bare noun (`titleStyle()`, `cardSegments()`).
