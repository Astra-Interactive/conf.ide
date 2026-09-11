## Module Organization Rule

Do not declare types inside function bodies, and do not bury helper types inside another type's file.

All domain models, services, helpers, factories, and implementations are top-level declarations: one
primary type per file.

Bad — type declared inside a function:

```rust
// prediction_model.rs
pub fn train() {
    struct Config {
        threshold: f32,
    }
    // ...
}
```

Bad — unrelated types grouped in one file:

```rust
// prediction_model.rs
pub struct PredictionModel { /* ... */ }
pub struct PredictionModelConfig { /* ... */ }
pub struct PredictionModelTrainer { /* ... */ }
```

Good — separate top-level types in separate files:

```rust
// prediction_model_config.rs
pub struct PredictionModelConfig {
    pub threshold: f32,
}
```

```rust
// prediction_model.rs
pub struct PredictionModel { /* ... */ }
```

```rust
// prediction_model_trainer.rs
pub struct PredictionModelTrainer { /* ... */ }
```

### Exceptions

* `enum`s are Rust's sealed hierarchies: variants, including struct-like variants, belong together in
  one declaration, in one file.

  ```rust
  // prediction_result.rs
  pub enum PredictionResult {
      Success { value: f32 },
      Failed { reason: FailureReason },
  }
  ```

* Test-only code is exempt. `#[cfg(test)] mod tests` at the bottom of a file, and the fakes and fixtures
  declared inside it, are not buried helper types: they are compiled only for tests and belong next to
  the code they exercise. The testing rule says where shared fakes live.

### Module files

Follow the layout the crate already uses: either `foo/mod.rs`, or `foo.rs` next to a `foo/` directory.
Do not mix the two styles in one crate. A new crate uses `foo.rs` + `foo/`, the Rust 2018 convention.
The module file declares the submodules and re-exports the types that form the module's API.

Do not use extra types or modules just for visual grouping.
