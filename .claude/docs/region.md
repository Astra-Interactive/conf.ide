## Code region rules

Region markers and artificial section delimiters are forbidden. There are no exceptions.

Forbidden examples:

```text
// region
// endregion
// #region
// #endregion
// --------
// ========
// === Helpers ===
```

Do not add decorative comments, separator comments, or "section header" comments. Existing markers in a
file are not a reason to add new ones. When you refactor a file that already has them, delete them.

Prefer simple, readable code structure instead:

* use small functions
* use meaningful names
* group related logic naturally
* rely on file/module structure instead of comment regions

Comments should explain non-obvious behavior, not organize the file visually.
