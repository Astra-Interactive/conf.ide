## Constructors Dependency Injection Rule

Never instantiate concrete dependencies inside a type's constructor (`new`/`from_*`), field initializers, or methods.

Dependencies must be created only at the composition root / application wiring layer, then passed down from parent to child.

Bad:

```rust
impl<R: OrderRepository> OrderService<R> {
    pub fn new(repository: R) -> Self {
        Self {
            repository,
            pricing: OrderPricing::new(DEFAULT_TAX_RATE), // hidden concrete dependency
            clock: SystemClock::new(),                    // hidden concrete dependency
        }
    }
}
```

Good:

```rust
impl<R: OrderRepository, C: Clock> OrderService<R, C> {
    pub fn new(repository: R, pricing: OrderPricing, clock: C) -> Self {
        Self {
            repository,
            pricing,
            clock,
        }
    }
}
```

When adding a new dependency, update the root wiring instead of calling `SomeImplementation::new()` inside the type.
