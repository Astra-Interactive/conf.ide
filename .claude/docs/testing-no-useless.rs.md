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
* edge cases (boundaries, empty and oversized input, malformed input at parsing boundaries)
* error handling
* integration between components
* regressions for known bugs

Before adding a test, ask: **Would this test fail if our project logic were broken?**

If the answer is no, do not write the test.

This rule complements the testing rule, it does not compete with it. The testing rule demands 100%
coverage of new code; this rule only removes tests that could never fail because they check the language
or a library rather than the project. A test that exercises project logic is never useless, however small
that logic is. If a line can be reached only by a test of this kind, the line itself is the problem: it
is dead code or belongs to a scenario you have not written yet.
