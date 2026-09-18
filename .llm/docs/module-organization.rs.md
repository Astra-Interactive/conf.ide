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

* Test-only code lives in the crate's `test/` tree, never in a source file, as the testing rule
  describes. Inside that tree fakes and fixtures used by one test module may share its file.

### Module files

A module is declared as an inline block in `src/lib.rs`; its files live in a directory of the same
name. Never create `foo/mod.rs` and never create `foo.rs` next to a `foo/` directory: the only
files under `src/` are the crate root (`lib.rs` or `main.rs`) and files that hold a type, and the
crate-layout rule says which single type file may sit directly next to the crate root.

```rust
// src/lib.rs
pub mod configuration {
    //! Module-level docs go here, inside the block.

    mod configuration_error;
    mod yaml_file;

    pub use configuration_error::ConfigurationError;
    pub use yaml_file::YamlFile;
}

pub mod lifecycle;
```

The compiler resolves `mod yaml_file;` inside `mod configuration { ... }` to
`src/configuration/yaml_file.rs`, so the block does the job of a module file without one more file
on disk. The block declares the submodules and re-exports the types that form the module's API, so
that callers write `crate::configuration::YamlFile`, never `crate::configuration::yaml_file::YamlFile`.
Nested concepts nest their blocks: `mod backend { ... }` inside `mod repository { ... }` reads
`src/repository/backend/`.

A concept that fits in a single file needs no block: `pub mod lifecycle;` loads `src/lifecycle.rs`.
That is a shape for the small crates the crate-layout rule exempts; past the exemption a file
joins a module.

Do not use extra types or modules just for visual grouping.
