## Rust Timestamp and Duration Rule

When writing Rust code, do not represent moments in time or durations as raw primitive types.

Avoid using:

```rust
u16
u32
u64
```

for time-related values in domain APIs.

### Bad

```rust
fn schedule_keep_alive(&mut self, interval_ms: u64)

struct ConnectionTiming {
    established_at: u64,
    read_timeout_ms: u32,
}
```

### Good

```rust
use std::time::{Duration, Instant};

fn schedule_keep_alive(&mut self, interval: Duration)

struct ConnectionTiming {
    established_at: Instant,
    read_timeout: Duration,
}
```

Use `core::time::Duration` for time intervals, delays, cooldowns, timeouts, and expiration lengths.

Use `std::time::Instant` for moments in time. Never pass a bare integer of milliseconds around a domain API.

Time that the code reads (rather than receives) must come from an injected `Clock` port, not from `Instant::now()` called inline — otherwise the logic is untestable.

Only convert timestamps or durations to raw integers at external boundaries: the wire format (title fade times in ticks, `readTimeout` in milliseconds), configuration parsing, serialization, or logging.
