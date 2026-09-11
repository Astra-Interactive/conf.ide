## Code ordering rules

When writing or modifying code, order declarations by dependency, not by call-site convenience.

### Layout of a file

1. `use` declarations, then `const`/`static` items, type aliases, and shared state come first, before any type or function.
2. Type definitions (`struct`, `enum`, `trait`) appear before the `impl` blocks and functions that use them.
3. Functions follow, ordered so that a callee is declared above its caller:
   - if function `A` calls function `B`, `B` appears before `A`;
   - private helpers sit above the functions that use them;
   - lower-level utilities come before higher-level orchestration functions.
4. Never append private helpers after the public functions that depend on them.
5. Trait implementations (`impl Trait for Type`) go after the type's inherent `impl` block.
6. `#[cfg(test)] mod tests` is the last item in the file.
7. Preserve this ordering when refactoring existing code.

### Inside an `impl` block

Associated constants come first. Functions then follow rule 3 exactly as they do at file level.
Constructors are not an exception: `new` usually lands near the top because it calls nothing, but when
it calls a validation helper, that helper is declared above `new`.

```rust
impl OrderPricing {
    const MAX_ITEMS: usize = 100;

    fn validate_tax_rate(tax_rate: f64) -> Result<f64, PricingError> {
        if !(0.0..=1.0).contains(&tax_rate) {
            return Err(PricingError::TaxRateOutOfRange { tax_rate });
        }
        Ok(tax_rate)
    }

    pub fn new(tax_rate: f64) -> Result<Self, PricingError> {
        let tax_rate = Self::validate_tax_rate(tax_rate)?;
        Ok(Self { tax_rate })
    }

    fn apply_tax(&self, subtotal: Money) -> Money {
        subtotal * (1.0 + self.tax_rate)
    }

    pub fn price_of(&self, order: &Order) -> Money {
        if order.items.len() > Self::MAX_ITEMS {
            return Money::ZERO;
        }
        self.apply_tax(order.subtotal())
    }
}
```
