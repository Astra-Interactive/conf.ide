## Rust Timestamp and Duration Rule

When writing Rust code, do not represent moments in time or durations as raw primitive or text types.
Which values are moments or durations is the reviewer's call.

Avoid using:

```rust
u32
u64
i64
f64
String
```

or any other integer or float for time-related values.

### Bad

```rust
created_at: i64,
expires_at: String,
timeout_seconds: u32,
```

### Good

```rust
use std::time::{Duration, SystemTime};

created_at: SystemTime,
expires_at: SystemTime,
timeout: Duration,
```

Use `std::time::SystemTime` for exact moments in time: it is the standard library's wall-clock type.
`std::time::Instant` is not a moment: it is monotonic and measures elapsed time inside one process, so it is
never stored, sent or shown.

Use `std::time::Duration` for time intervals, delays, cooldowns, timeouts, and expiration lengths.

Only convert moments or durations to integers or strings at external boundaries, such as database storage,
serialization, logging, or a wire format. A call that takes only an integer (`set_timeout_millis(u64)`) is
such a boundary: the constant stays a `Duration` (`const CARD_IN: Duration = Duration::from_millis(400);`,
never `const CARD_IN_MS: u64 = 400;`), and the conversion is written at that call; a literal at the call is
already at the boundary. A call that takes a `Duration` (`tokio::time::sleep(delay)`) gets the `Duration`.

### Time crates and the system clock

- A time crate (`chrono`, `time`, `jiff`) is used only in a technology module or crate, or in a `contract`
  crate, where a library or the wire format demands it, and its values are converted to `SystemTime` and
  `Duration` there. A project uses one time crate at most: each brings its own moment type, and two of them
  bring conversions between each other's types, which is what Kotlin avoids by using only `kotlin.time`.
- The current moment comes from the project's `Clock` trait, `fn now(&self) -> SystemTime`. Kotlin takes
  `kotlin.time.Clock` from its standard library; Rust's has no clock trait, so the project declares one, as any
  contract: in `core` when two or more units use it at creation, else in the `api` of the unit that needs it; a
  later consumer uses it where it is (`arch-package.md`, Existing code). Its production implementation,
  `SystemClock`, sits in the technology module `system` of the same concept (`arch-package.rs.md`, Modules and
  directories) and is the one place that calls `SystemTime::now()`; a test fake implements `Clock` too:

  ```rust
  // clock/system/system_clock.rs
  pub(crate) struct SystemClock;

  impl Clock for SystemClock {
      #[expect(
          clippy::disallowed_methods,
          reason = "SystemClock is the one reader of the system clock"
      )]
      fn now(&self) -> SystemTime {
          SystemTime::now()
      }
  }
  ```

  An elapsed time comes from `std::time::Instant::now()`. No other clock read is called: not `SystemTime::now()`
  elsewhere, not `chrono::Utc::now()`, not `jiff::Timestamp::now()`. A struct takes the `Clock` through its
  constructor, and the DI module passes `SystemClock` (`di-manual-constructors.rs.md`).
- `clippy.toml` lists the clock reads under `disallowed-methods`: `std::time::SystemTime::now` and
  `std::time::SystemTime::elapsed`, which reads the wall clock too (`UNIX_EPOCH.elapsed()`), and the time crates'
  `chrono::Utc::now`, `chrono::Local::now`, `jiff::Timestamp::now`, `jiff::Zoned::now`,
  `time::OffsetDateTime::now_utc`, `time::OffsetDateTime::now_local` and `time::UtcDateTime::now`, each of these
  seven time-crate entries with `allow-invalid = true`. Such an entry reports a call wherever its crate is a dependency and is silent
  elsewhere. Without `allow-invalid`, an entry whose function the build lacks (`chrono` without its `now` feature
  has no `Utc::now`) prints a configuration warning in every crate that depends on that build, and `-D warnings`
  does not turn it into an error.
