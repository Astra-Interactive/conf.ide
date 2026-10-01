## Rust Closure Naming Rule

When writing Rust code, never use meaningless single-letter closure parameter names like `x`, `v`, `r`, `e`.

Always give closure parameters explicit, meaningful names.

### Bad

```rust
get_request().map(|r| {
    log(&r);
});
```

### Good

```rust
get_request().map(|request| {
    log(&request);
});
```

Use names that describe the value.

Allowed exceptions:

* `_` (or `_name`) for genuinely unused parameters.
* Conventional short names in tight, local numeric code (`i` for an index in a short loop body).
