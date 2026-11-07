## Rust: No Console Output

When writing Rust code, never write to the console. `print!`, `println!`, `eprint!`, `eprintln!`, `dbg!`,
`std::io::stdout()` and `std::io::stderr()` are not called, in tests either.

Every message goes through the logging crate the project uses (`tracing`, `log`). A caught error is passed to
the logger as a field of the event, which keeps its `source()` chain, not only formatted into the message.

### Bad

```rust
if let Err(error) = load_order(order_id) {
    eprintln!("Could not load order: {error}");
    dbg!(&error);
}
```

### Good

```rust
if let Err(error) = load_order(order_id) {
    tracing::warn!(
        error = &error as &dyn std::error::Error,
        "Could not load order"
    );
}
```

The one exception is a command-line entry point whose product is the console output, such as an `xtask`
report: the function that writes carries `#[expect(clippy::print_stdout, reason = "…")]`, or
`#[expect(clippy::disallowed_methods, reason = "…")]` when it writes through `std::io::stdout()`, with the
reason written in it.
