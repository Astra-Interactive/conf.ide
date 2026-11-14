## Struct Default Values Rule

Do not give a struct or an enum default values: no `#[derive(Default)]`, no `impl Default`. Rust has no default
arguments, so `Default` and the struct update it enables (`..Default::default()`) are how a field gets a value
the caller did not pass.

Rust has no data-class keyword, so the rule covers every struct and enum; the exceptions below leave out the
types that are not data.

Bad:

```rust
#[derive(Default)]
pub(crate) struct PredictionInput {
    pub(crate) symbol: String,
    pub(crate) window: u16,
    pub(crate) features: Vec<f64>,
}

let input = PredictionInput {
    window: 100,
    ..Default::default()
};
```

Good:

```rust
pub(crate) struct PredictionInput {
    pub(crate) symbol: String,
    pub(crate) window: u16,
    pub(crate) features: Vec<f64>,
}

let input = PredictionInput {
    symbol: symbol.to_owned(),
    window: 100,
    features: Vec::new(),
};
```

Allowed exceptions:

* A type that derives or implements `serde::Deserialize`, where defaults are required for serialization/backward
  compatibility: it may implement or derive `Default` and carry `#[serde(default)]`, except a model type with an
  invariant (`arch-domain.rs.md`).

  ```rust
  // a config read from a file; the defaults keep old files readable
  #[derive(Deserialize)]
  #[serde(default)]
  pub(crate) struct PredictionConfig {
      pub(crate) symbol: String,
      pub(crate) window: u16,
      pub(crate) features: Vec<f64>,
  }

  impl Default for PredictionConfig {
      fn default() -> Self {
          Self {
              symbol: String::new(),
              window: 100,
              features: Vec::new(),
          }
      }
  }
  ```

* A type whose constructor takes no argument (`pub fn new() -> Self`) derives `Default` or implements it by
  calling `new`: `clippy::new_without_default` demands it for a public `new`, and such a type has no value for
  a caller to pass.
* A type that a library's API requires to implement `Default` (a `T: Default` bound of a function the project
  calls); whether the bound requires it is the reviewer's call.

If a type is not deserialized, do not give it defaults. Pass values explicitly from the caller/root wiring.
