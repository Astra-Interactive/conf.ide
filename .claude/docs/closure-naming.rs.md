## Rust Closure Naming Rule

When writing Rust code, give every closure parameter a name that says what it holds, never a single character:
not `|r|`, not `|x|`, not the index in `|(i, line)|`. A one-letter parameter is a name that carries nothing.

Never name anything `it`: not a closure parameter, not a function parameter, not a `let` or `match` binding,
not a field, not a loop label (`'it: loop`).

`_` and a name that starts with `_` (`_event`) mark a parameter the body does not use; they stay.

A method of an `impl Trait for` block may name a parameter differently from the trait: Rust has no named
arguments, so renaming an `it` there changes no caller.

### Bad

```rust
let overdue = invoices.iter().filter(|i| i.due_at < now && !i.is_paid);
let rows = lines
    .iter()
    .enumerate()
    .map(|(n, line)| format!("{n}: {line}"));
```

### Good

```rust
let overdue = invoices
    .iter()
    .filter(|invoice| invoice.due_at < now && !invoice.is_paid);
let rows = lines
    .iter()
    .enumerate()
    .map(|(index, line)| format!("{index}: {line}"));
```

Use names that describe the value.
