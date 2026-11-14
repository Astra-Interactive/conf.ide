## Code ordering rules

When writing or modifying code, order declarations by dependency, not by call-site convenience.

### Layout of a file or scope

1. `use` declarations come first, then the file's `const` and `static` items and shared state, before any type
   or function. The constants of one struct or enum are not among them: they close its `impl` (Exception
   below).
2. Then the file's type: its definition, its inherent `impl` block, then its trait `impl` blocks, then the data
   types only it uses, each with its own `impl` blocks. Inside an `impl` block the constructors come first:
   `new`, `with_…`, `from_…`, every associated function without a `self` receiver that returns `Self`,
   `Result<Self, _>` or `Option<Self>` (std's `File::open`), the type's own name counting as `Self`. In a trait
   `impl`, the associated types and constants the trait requires come first.
3. Functions follow, ordered so that a callee is declared above its caller:
   - if function `a` calls function `b`, `b` appears before `a`;
   - private helpers sit above the functions that use them;
   - lower-level utilities come before higher-level orchestration functions.

   This order holds inside one `impl` block and among the free functions of a file that declares no type (a
   `type` alias is no type declaration here).
   A constructor is never a caller here: it stays first by rule 2 and may call a helper declared below it, as
   `TaskScope::new` calls `drain` (`async.rs.md`, Tasks), the way a Kotlin secondary constructor precedes the
   functions whatever it calls. Between `impl` blocks rule 2 wins: an inherent method may call a trait method
   declared below it, because each method lives in exactly one block and calls between blocks go both ways.
4. Never append private helpers after the public functions that depend on them.
5. Preserve this ordering when refactoring existing code.

```rust
pub(crate) struct OrderPricing {
    tax_rate: f64,
}

impl OrderPricing {
    pub(crate) fn new(tax_rate: f64) -> Self {
        Self { tax_rate }
    }

    fn apply_tax(&self, subtotal: Money) -> Money {
        subtotal * (1.0 + self.tax_rate)
    }

    pub(crate) fn compute_price(&self, order: &Order) -> Money {
        if order.items.len() > Self::MAX_ITEMS {
            return Money::ZERO;
        }
        self.apply_tax(order.subtotal)
    }

    const MAX_ITEMS: usize = 100;
}
```

### Exception: associated constants close the `impl`

Inside the inherent `impl` the associated constants are the last declarations, and the constants of a struct or
enum (`const` limits, keys, shared defaults) live there. Rule 1 covers the constants of a file that declares no
struct or enum; it does not pull a type's constants to the top of the file.

This holds for a DI module too. A unit struct, an empty enum or a module beside a type that only holds that
type's constants is forbidden.

```rust
// Bad
struct FeatureFlagModuleDefaults;

impl FeatureFlagModuleDefaults {
    const RELOAD_INTERVAL: Duration = Duration::from_secs(60);
}

pub(crate) struct FeatureFlagModule {
    pub(crate) feature_flag_reloader: Arc<IntervalFeatureFlagReloader>,
}

impl FeatureFlagModule {
    pub(crate) fn new(core_module: &CoreModule) -> Self {
        let feature_flag_reloader = Arc::new(IntervalFeatureFlagReloader::new(
            FeatureFlagModuleDefaults::RELOAD_INTERVAL,
            Arc::clone(&core_module.task_scope),
        ));
        Self {
            feature_flag_reloader,
        }
    }
}

// Good
pub(crate) struct FeatureFlagModule {
    pub(crate) feature_flag_reloader: Arc<IntervalFeatureFlagReloader>,
}

impl FeatureFlagModule {
    pub(crate) fn new(core_module: &CoreModule) -> Self {
        let feature_flag_reloader = Arc::new(IntervalFeatureFlagReloader::new(
            Self::RELOAD_INTERVAL,
            Arc::clone(&core_module.task_scope),
        ));
        Self {
            feature_flag_reloader,
        }
    }

    const RELOAD_INTERVAL: Duration = Duration::from_secs(60);
}
```

Two kinds of constant stay at the top of the file under rule 1, because Rust has no other place for them:

- a constant of a trait itself, one with a value: a trait with an associated constant cannot be used as
  `dyn Trait`. An associated constant without a value, which each implementation supplies, stays in the trait;
- every `static`: Rust has no associated statics.
