## Rust Timestamp and Duration Rule

When writing Rust code, do not represent moments in time or durations as raw primitive or text types.

Avoid `u16`, `u32`, `u64`, `i64`, `String` for time-related values in domain APIs.

### Which type

| Value                                                                                  | Type                    |
|----------------------------------------------------------------------------------------|-------------------------|
| Interval, timeout, delay, cooldown, TTL                                                | `std::time::Duration`   |
| Moment measured by this process only: elapsed time, deadlines, rate limiting           | `std::time::Instant`    |
| Moment that is stored, transmitted, displayed, or compared with the outside world      | `chrono::DateTime<Utc>` |

`std::time::Duration` and `core::time::Duration` are the same type; write `std::time::Duration` in a
`std` crate and `core::time::Duration` only in `no_std` code.

`Instant` is monotonic and unrelated to the calendar: it cannot be serialized, formatted, or compared
across processes. Never store it and never use it for a timestamp a user or another system will see.

For wall-clock time the standard library offers only `SystemTime`, which cannot be formatted or parsed
without a crate. Use `chrono`: `DateTime<Utc>` in domain types, always UTC, converted to a local zone
only at the presentation boundary. `chrono` is the most widely used time crate and the one every
serialization, database and logging crate integrates with. If the project already depends on `time` or
`jiff`, use that crate's types instead; never add a second time crate.

### Bad

```rust
fn schedule_retry(&mut self, delay_ms: u64)

struct OrderTiming {
    created_at: i64,
    payment_timeout_ms: u32,
}
```

### Good

```rust
use std::time::Duration;

use chrono::{DateTime, Utc};

fn schedule_retry(&mut self, delay: Duration)

struct OrderTiming {
    created_at: DateTime<Utc>,
    payment_timeout: Duration,
}
```

Time that the code reads (rather than receives) must come from an injected `Clock` port, not from
`Instant::now()` or `Utc::now()` called inline — otherwise the logic is untestable.

Only convert timestamps or durations to raw integers or strings at external boundaries: the wire format,
configuration parsing, serialization, or logging.
