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
name. Never create `foo/mod.rs`, and never create `foo.rs` at the crate root at all: `src/` holds
`lib.rs` and nothing else, in every crate of the workspace, `library/*` included (crate-layout
rule). Every other file under `src/` sits in a module directory and holds a type.

```rust
// src/lib.rs
pub mod configuration {
    //! Module-level docs go here, inside the block.

    mod configuration_error;
    mod yaml_file;

    pub use configuration_error::ConfigurationError;
    pub use yaml_file::YamlFile;
}

pub mod permission {
    //! One sentence on what the concept is for, even when it holds a single type.

    mod permission_registration_error;

    pub use permission_registration_error::PermissionRegistrationError;
}
```

The compiler resolves `mod yaml_file;` inside `mod configuration { ... }` to
`src/configuration/yaml_file.rs`, so the block does the job of a module file without one more file
on disk. The block declares the submodules and re-exports the types that form the module's API, so
that callers write `crate::configuration::YamlFile`, never `crate::configuration::yaml_file::YamlFile`.
Nested concepts nest their blocks: `mod backend { ... }` inside `mod repository { ... }` reads
`src/repository/backend/`.

A concept with one type still gets its directory and its block, as `permission` does above. The
block costs four lines, and there is no shape in between for a concept to wait in.

Bad — a concept parked at the crate root:

```rust
// src/permission.rs
pub struct PermissionRegistrationError { /* ... */ }
```

Good — the concept's directory, from its first file:

```rust
// src/permission/permission_registration_error.rs
pub struct PermissionRegistrationError { /* ... */ }
```

A file is named after the type it holds, always. When that name would repeat the module's name,
`clippy::module_inception` refuses the file — and the lint is right: the module has been named
after its type instead of after the area the type belongs to. Widen the module; never decorate the
file to get past the lint. `library/core/src/time/` holds `Clock` and `SystemClock`;
`library/pumpkin/src/scheduling/` holds `Scheduler`, `ScheduledTask`, `TaskHandle` and
`HostScheduler`. A suffix invented for the file instead (`scheduler_port.rs`) claims a role the
type may not have and leaves the file name disagreeing with what is in it.

Do not use extra types or modules just for visual grouping.
