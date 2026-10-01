# Kotlin imports guidelines

- Never use wildcard imports (e.g., `import foo.*`)
- Always use explicit imports
- Imports are ordered the way detekt's `ImportOrdering` rule checks them, the ktlint layout
  `*,java.**,javax.**,kotlin.**,^`, with no blank lines between the groups:
  1. every other import, sorted alphabetically by full path; `kotlinx.*` belongs here, not to `kotlin.*`;
  2. `java.*`, then `javax.*`, then `kotlin.*`, each group sorted alphabetically;
  3. aliased imports (`import … as …`) last.
- When the project's detekt config sets another `layout` for `ImportOrdering`, that layout wins.

```kotlin
import kotlinx.coroutines.flow.StateFlow
import platform.Foundation.NSLocale
import ru.astrainteractive.klibs.mikro.core.logging.api.Logger
import java.io.File
import kotlin.time.Duration
import java.util.logging.Logger as JLogger
```
