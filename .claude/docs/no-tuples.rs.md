## No Anonymous Tuples

Do not use tuples for typed/domain data in public APIs, struct fields, or return types.

Use a small named struct instead, with meaningful field names.

Example:

```rust
// Bad
fn position(&self) -> (i32, i32)
fn line_items(&self) -> Vec<(ProductId, u32)>

// Good
pub struct Point {
    pub x: i32,
    pub y: i32,
}
fn position(&self) -> Point

pub struct LineItem {
    pub product_id: ProductId,
    pub quantity: u32,
}
fn line_items(&self) -> Vec<LineItem>
```

Not covered by this rule:

* The unit type `()`. `Result<(), E>` is the normal signature of a fallible operation with no value.
* Tuples produced by the standard library and consumed on the spot: destructuring `enumerate()`, `zip()`,
  or a map's `(key, value)` pairs inside a function body.

A tuple is a transient local value, never a domain type crossing an API boundary.
