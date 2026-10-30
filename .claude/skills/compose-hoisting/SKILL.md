---
name: compose-hoisting
description: Use this skill when working with @Composable functions, Decompose screen components, or Compose previews in this project. Applies when asked to "add previews", "refactor composable", "hoist state", or when editing any file containing @Composable annotations or a component's `Render()`.
version: 1.0.0
---

# Compose State Hoisting & Decompose

Enforce state-hoisting for `@Composable` functions and extract layout from a component's `Render()` into dedicated composables.

## Rules

### 1. State-hoisted `@Composable` functions

Every `@Composable` function must accept only models, event handlers, a `Modifier` and Compose's own state objects (`SnackbarHostState`, `LazyListState`). It holds no internal `var … by remember { mutableStateOf(…) }`, with two exceptions: UI mechanics (scroll position, focus holder) may live in any composable; UI toggles with no business meaning (password visibility, expansion) may live only in the screen-level composable (rule 3), and every composable it calls takes that state as a parameter. Loading flags and form values are always parameters.

```kotlin
// ✅ correct
@Composable
internal fun PasswordFieldComposable(
    value: String,
    isHidden: Boolean,
    onHiddenChange: (Boolean) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
)

// ❌ wrong — a UI toggle below the screen level
@Composable
internal fun PasswordFieldComposable(...) {
    var isHidden by remember { mutableStateOf(true) }  // hoist this
}
```

### 2. A component's `Render()` — collect state only

`Render()` holds only `collectAsState()` calls, the Compose state objects the events act on (`remember { SnackbarHostState() }`), at most one `LaunchedEffect` that collects the component's one-off events (`no-callbacks.kt.md`), and a single delegating composable call. No `Column`, no `padding`, no `AppBar`, no layout whatsoever.

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

### 3. Screen-level composable (`*ScreenComposable`)

When extracting layout from `Render()`, create a `*ScreenComposable` file/function. This composable:
- Owns the UI toggles (password visibility, expansion)
- Contains the outer scaffold: `Column`, `AppBar`, `navigationBarsPadding`, `fillMaxSize`
- Calls the inner content composable (which must itself be fully state-hoisted)

**Naming:** `<Feature>ScreenComposable`

```kotlin
@Composable
internal fun ConfirmPasswordScreenComposable(
    confirmPasswordType: ConfirmPasswordType,
    state: ConfirmPasswordState,
    fields: PasswordFieldsContent,
    onBack: () -> Unit,
    onConfirm: () -> Unit,
    onPasswordFieldChange: (String) -> Unit,
    onConfirmFieldChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var passwordFieldHidden by remember { mutableStateOf(true) }  // pure UI toggle — OK here

    Column(modifier.fillMaxSize().navigationBarsPadding()) {
        LogInAppBarComposable(text = confirmPasswordType.textTitle, onBack = onBack)
        ConfirmPasswordContentComposable(
            passwordFieldHidden = passwordFieldHidden,
            onPasswordFieldHiddenChange = { hidden -> passwordFieldHidden = hidden },
            ...
        )
    }
}
```

### 4. Previews

Add `@Preview` functions at the **bottom of the file** they preview. Rules:
- Always wrap with the project's theme composable (`AppTheme { }`)
- Always `private`
- Cover: default/empty state, filled/enabled state, in-progress/loading state, error/invalid state
- Name pattern: `<Composable><Scenario>Preview`, `<Composable>` being the composable's name without `Composable`
  (`PasswordFieldComposable` → `PasswordFieldEmptyPreview`)

```kotlin
@Preview
@Composable
private fun PasswordFieldEmptyPreview() {
    AppTheme {
        PasswordFieldComposable(
            value = "",
            isHidden = true,
            onHiddenChange = {},
            onSubmit = {}
        )
    }
}

@Preview
@Composable
private fun PasswordFieldFilledPreview() {
    AppTheme {
        PasswordFieldComposable(
            value = "Hello",
            isHidden = false,
            onHiddenChange = {},
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
3. If a component's `Render()` contains layout: extract it into a new `*ScreenComposable` file, update `Render()` to only collect state and events and call it.
4. Add previews at the bottom of each composable file covering all meaningful visual states.
5. Apply focus/autofill preview guards where `LaunchedEffect { requestFocus() }` or `autofill {}` modifier is present.
