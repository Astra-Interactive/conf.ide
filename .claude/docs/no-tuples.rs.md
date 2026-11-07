## No Anonymous Tuples

Do not use tuples for typed/domain data. A tuple of two or more elements is never the type of a field, a
parameter, a return value, a type alias, a `const` or `static`, or a type argument (`Vec<(ProductId, u32)>`),
whatever the item's visibility. Inside a function body a tuple is destructured where it appears
(`let (head, tail) = text.split_at(index);`, `for (index, line) in lines.iter().enumerate()`,
`match (state, event)`) or passed straight to an API that takes tuples (`HashMap::from([(key, value)])`, a
closure whose `(key, value)` result `collect` gathers into a map); it is never bound to one name
(`let parts = text.split_at(index);`).

Use a small struct instead, with meaningful field names. A tuple struct or a tuple variant of two or more fields
(`struct Point(i32, i32)`) is an anonymous tuple under a type name: its fields need names too.

Not covered by this rule:

* The unit type `()`. `Result<(), E>` is the normal signature of a fallible operation with no value.
* A method of an `impl Trait for` block, whose signature the trait gives (`Iterator::size_hint` returns
  `(usize, Option<usize>)`).

Example:

```rust
// Bad
fn position(&self) -> (i32, i32)
fn line_items(&self) -> Vec<(ProductId, u32)>
let parts = text.split_at(index);

// Good
pub(crate) struct Point {
    pub(crate) x: i32,
    pub(crate) y: i32,
}

pub(crate) struct LineItem {
    pub(crate) product_id: ProductId,
    pub(crate) quantity: u32,
}

fn position(&self) -> Point
fn line_items(&self) -> Vec<LineItem>
let (head, tail) = text.split_at(index);
```
