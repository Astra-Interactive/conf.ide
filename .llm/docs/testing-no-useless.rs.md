# Testing Guidelines

Do not write tests that only verify language/library behavior or trivial data storage.

Avoid tests like:

```rust
struct MyStruct {
    value: i32,
}

let my_struct = MyStruct { value: 10 };
assert_eq!(10, my_struct.value);
```

This only tests that Rust struct fields work.

Write tests only when they verify meaningful project behavior, such as:

* business logic
* validation rules
* edge cases (varint boundaries, string length limits, bit packing, truncated network input)
* error handling
* integration between components
* regressions for known bugs

Before adding a test, ask: **Would this test fail if our project logic were broken?**

If the answer is no, do not write the test.
