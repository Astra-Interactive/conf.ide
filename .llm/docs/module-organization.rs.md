## No Nested Types Rule

Do not declare types inside function bodies or bury helper types inside another type's file.

All domain models, services, helpers, factories, and implementations must be top-level declarations — one primary type per file, re-exported through `mod.rs`.

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

Allowed exception: `enum`s are Rust's sealed hierarchies — variants (including struct-like variants) belong together in one declaration, in one file:

```rust
// prediction_result.rs
pub enum PredictionResult {
    Success { value: f32 },
    Failed { reason: FailureReason },
}
```

Do not use extra types or modules just for visual grouping. Only enum variants live together; everything else gets its own file. Follow the existing layout: one type per file, `mod.rs` declares and re-exports the module's files.
