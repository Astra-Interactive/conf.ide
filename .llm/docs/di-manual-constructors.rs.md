## Constructors Dependency Injection Rule

Never instantiate concrete dependencies inside a type's constructor (`new`/`from_*`), field initializers, or methods.

Dependencies must be created only at the composition root / application wiring layer, then passed down from parent to child.

Bad:

```rust
impl<D: Display> SceneRenderer<D> {
    pub fn new(display: D) -> Self {
        Self {
            display,
            rotator: Rotator::new(),           // hidden concrete dependency
            trigonometry: Trigonometry::new(), // hidden concrete dependency
        }
    }
}
```

Good:

```rust
impl<D: Display> SceneRenderer<D> {
    pub fn new(display: D, rotator: Rotator, trigonometry: Trigonometry) -> Self {
        Self {
            display,
            rotator,
            trigonometry,
        }
    }
}
```

When adding a new dependency, update the root wiring instead of calling `SomeImplementation::new()` inside the type.
