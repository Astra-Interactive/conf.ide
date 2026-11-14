# Testing Guidelines

Do not write tests that only verify language/library behavior or trivial data storage.

Avoid tests like:

```rust
#[derive(Debug, Clone, PartialEq)]
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
* edge cases
* error handling
* integration between components
* regressions for known bugs

Before adding a test, ask: **Would this test fail if our project logic were broken?**

If the answer is no, do not write the test.

The testing rule demands 100% line coverage and 100% branch coverage of new code that implements project
behaviour. Generated code and trivial field storage are outside this denominator, so they need no tests
that merely repeat language or library behaviour. Generated code is what a derive or a macro writes
(`#[derive(Debug, Clone, PartialEq)]`, a `thiserror` `Display`); rustc gives the impls of the standard derives
no coverage counter, so they are outside the measured lines too. An uncovered line of that excluded code is
not, by itself, dead code. Host glue, as `testing.rs.md` defines it, is outside the denominator too, by what it
does: it only hands values to and from the host.

The check of a type's invariant is project behaviour and needs valid and invalid input scenarios
(`Money::try_from` with a negative amount, `parse_money` with text that is not a number); checking that a struct
stored the value it was built with is not. The exclusion is by what the code does, never by its module:
`model`, `di` and entry points may all contain behaviour that must be covered. Meaningful integration tests can
cover wiring and lifecycle ordering without a dedicated test file for each type. If new project behaviour
remains uncovered, add the missing scenario or establish that the code is dead; do not classify it as trivial
merely to reach the coverage target.
