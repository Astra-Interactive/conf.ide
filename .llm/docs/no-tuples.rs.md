## No Anonymous Tuples

Do not use tuples for typed/domain data in public APIs, struct fields, or return types.

Use a small named struct instead, with meaningful field names.

Example:

```rust
// Bad
fn position(&self) -> (i32, i32)
fn readings(&self) -> [(u8, u16); 4]

// Good
pub struct Point {
    pub x: i32,
    pub y: i32,
}
fn position(&self) -> Point

pub struct SensorReading {
    pub channel: u8,
    pub value: u16,
}
fn readings(&self) -> [SensorReading; 4]
```

Tuples are acceptable only as transient local values (e.g. destructuring `enumerate()` inside a function body), never as a domain type crossing an API boundary.
