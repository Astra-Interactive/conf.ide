---
name: compose-hoisting
description: Use this skill when working with @Composable functions, Decompose screen components, or Compose previews in this project. Applies when asked to "add previews", "refactor composable", "hoist state", or when editing any file containing @Composable annotations or DecomposeComponent.Render() implementations.
version: 1.0.0
---

# Compose State Hoisting & Decompose

Enforce state-hoisting for `@Composable` functions and extract layout from `DecomposeComponent.Render()` into dedicated composables.

## Rules

### 1. State-hoisted `@Composable` functions

Every `@Composable` function must accept only models and callbacks — no internal `var … by remember { mutableStateOf(…) }` unless the state is purely local UI mechanics with no business meaning (e.g. scroll position, focus holder). Password visibility toggles, loading flags, form values — all must be parameters.

```kotlin
// ✅ correct
@Composable
fun MyComposable(
    value: String,
    isHidden: Boolean,
    onHiddenChange: (Boolean) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
)

// ❌ wrong — owns business-relevant state
@Composable
fun MyComposable(...) {
    var isHidden by remember { mutableStateOf(true) }  // hoist this
}
```

### 2. `DecomposeComponent.Render()` — collect state only

`Render()` must contain nothing but `collectAsState()` calls and a single delegating composable call. No `Column`, no `padding`, no `AppBar`, no layout whatsoever.

```kotlin
// ✅ correct
@Composable
override fun Render(modifier: Modifier) {
    val uiState by viewModel.state.collectAsState()
    MyScreenComposable(
        modifier = modifier,
        uiState = uiState,
        onAction = viewModel::onAction,
    )
}

// ❌ wrong — layout lives in Render()
@Composable
override fun Render(modifier: Modifier) {
    Column(modifier.fillMaxSize().navigationBarsPadding()) {
        AppBarComposable(...)
        val state by viewModel.state.collectAsState()
        MyScreenComposable(...)
    }
}
```

### 3. Screen-level composable (`*ComposableScreen`)

When extracting layout from `Render()`, create a `*ComposableScreen` file/function. This composable:
- Owns pure-UI state that has no business meaning (password visibility, expansion toggles)
- Contains the outer scaffold: `Column`, `AppBar`, `navigationBarsPadding`, `fillMaxSize`
- Calls the inner content composable (which must itself be fully state-hoisted)

**Naming:** `Auth<Feature>ComposableScreen` / `<Feature>ComposableScreen`

```kotlin
@Composable
fun AuthConfirmPasswordComposableScreen(
    confirmPasswordType: InternalConfirmPasswordType,
    screenState: ConfirmPasswordScreenState,
    fieldsState: PasswordFieldsState,
    onBack: () -> Unit,
    onConfirm: () -> Unit,
    onPasswordFieldChange: (String) -> Unit,
    onConfirmFieldChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var passwordFieldHidden by remember { mutableStateOf(true) }  // pure UI toggle — OK here

    Column(modifier.fillMaxSize().navigationBarsPadding()) {
        LogInAppBarComposable(text = confirmPasswordType.textTitle, onBack = onBack)
        ConfirmPasswordScreenComposable(
            passwordFieldHidden = passwordFieldHidden,
            onPasswordFieldHiddenChange = { passwordFieldHidden = it },
            ...
        )
    }
}
```

### 4. Previews

Add `@Preview` functions at the **bottom of the file** they preview. Rules:
- Always wrap with `BusyBarThemeInternal { }`
- Always `private`
- Cover: default/empty state, filled/enabled state, in-progress/loading state, error/invalid state
- Name pattern: `<ComposableName><Scenario>Preview`

```kotlin
@Preview
@Composable
private fun MyComposableEmptyPreview() {
    BusyBarThemeInternal {
        MyComposable(
            value = "",
            onSubmit = {}
        )
    }
}

@Preview
@Composable
private fun MyComposableFilledPreview() {
    BusyBarThemeInternal {
        MyComposable(
            value = "Hello",
            onSubmit = {}
        )
    }
}
```

### 5. Preview safety — focus and autofill

Two patterns crash previews and must be guarded:

**Auto-focus via `LaunchedEffect`** — skip in inspection mode:
```kotlin
val isInspectionMode = LocalInspectionMode.current
LaunchedEffect(focusRequester) {
    if (!isInspectionMode) {
        focusRequester.requestFocus()
    }
}
```

**Autofill `requestAutofillForNode`** — guard against null bounding box (fires before `onGloballyPositioned`):
```kotlin
.onFocusChanged { focusState ->
    autofill?.run {
        if (focusState.isFocused && autofillNode.boundingBox != null) {
            requestAutofillForNode(autofillNode)
        } else if (!focusState.isFocused) {
            cancelAutofillForNode(autofillNode)
        }
    }
}
```

## Workflow

When asked to "add previews" to a directory or file:

1. Read every `@Composable` file in scope.
2. For each composable — check state-hoisting. If it has internal `var … mutableStateOf`, hoist the state as parameters; find the caller and pass the state down (or create a screen-level wrapper if none exists).
3. If a `DecomposeComponent.Render()` contains layout: extract it into a new `*ComposableScreen` file, update `Render()` to only collect state and call it.
4. Add previews at the bottom of each composable file covering all meaningful visual states.
5. Apply focus/autofill preview guards where `LaunchedEffect { requestFocus() }` or `autofill {}` modifier is present.
