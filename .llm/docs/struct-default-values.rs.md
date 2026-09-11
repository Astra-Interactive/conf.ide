## Struct Default Values Rule

Do not derive or implement `Default` for domain structs, and do not fill fields with `..Default::default()`.

Bad:

```rust
#[derive(Default)]
pub struct PredictionInput {
    pub symbol_id: u8,
    pub window: u16,
    pub threshold: f32,
}

let input = PredictionInput {
    window: 100,
    ..Default::default()
};
```

Good:

```rust
pub struct PredictionInput {
    pub symbol_id: u8,
    pub window: u16,
    pub threshold: f32,
}

let input = PredictionInput {
    symbol_id: 1,
    window: 100,
    threshold: 0.5,
};
```

Allowed exceptions:

* DTOs where defaults are required for serialization/backward compatibility (e.g. `serde` types using `#[serde(default)]`).
* Implementing `Default` when an external crate's API contractually requires it.
* A type whose constructor takes no arguments. `clippy::new_without_default` fires on a public
  `fn new() -> Self` without parameters, and clippy runs with `-D warnings`, so such a type derives
  `Default` or implements it by delegating to `new`. This is consistent with the rule: it protects
  against a caller silently skipping a field that needed a value, and a type with nothing to configure
  has no such field. `..Default::default()` stays forbidden even for these types.

If a struct is not serialized, do not give it defaults. Pass values explicitly from the caller/root wiring.
