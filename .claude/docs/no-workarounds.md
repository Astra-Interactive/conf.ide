## No workarounds

A fix explains why the failure happened. A change that makes the failure disappear without that
explanation is a workaround, and it is reverted when it is found.

### What counts as a workaround

Each of these has been written into this codebase by an agent and taken out again:

* a `delay`, `sleep`, poll, retry loop or timeout added to hide a race or an ordering problem;
* catching a broad exception type, swallowing a cancellation or a task's `JoinError`, wrapping the symptom
  in `runCatching` or `unwrap_or_default` so that the error does not surface;
* a suppression annotation, a lint baseline, a disabled rule, a lint error turned into a warning;
* a keep-alive, a lock in multiplatform code, a blocking call inside suspending or `async` code (a Rust lock
  whose guard no `.await` crosses is not one: `async.rs.md`, Shared state and locks), a reflection call, a
  hard-coded value where the real value could not be found;
* turning off a build feature (isolated projects, the configuration cache, a test) because it failed;
* a cast or a null check that silences the compiler where the type was wrong;
* a fix in the consumer of a library for a bug that is in the library.

### What to do instead

1. Find the cause and cite it: the line, the log, the experiment that showed it.
2. Fix it there. If the cause is outside the task's scope, say so and stop; do not patch around it.
3. When a workaround is the only option, it is a decision the user makes, not the agent: name the
   cause, the workaround, and what it costs, and wait. An approved workaround carries a comment that
   points at the external cause (the issue, the platform bug) and nothing else.

A task that ends with a workaround the user did not approve is not done.
