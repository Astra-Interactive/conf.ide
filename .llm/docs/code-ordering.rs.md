## Code ordering rules

When writing or modifying code, order declarations by dependency, not by call-site convenience.

Required order:

1. `use` declarations, then `const`/`static` items, type aliases, configuration, and shared state at the top of the file, before functions.
2. Type definitions (`struct`, `enum`, `trait`) must appear before the `impl` blocks and functions that use them.
3. Private helper functions must be placed above the functions that use them.
4. If function `A` calls function `B`, then `B` must appear before `A`.
5. Lower-level utilities should appear before higher-level orchestration functions.
6. Do not place dependent helper functions at the bottom of the file.
7. Do not append private functions after public functions when those public functions depend on them.
8. Within an `impl` block: associated constants first, then constructors (`new`, `from_*`), then private helper methods, then the public methods that use them.
9. Trait implementations (`impl Trait for Type`) go after the type's inherent `impl` block.
10. Preserve this ordering when refactoring existing code.
11. `#[cfg(test)] mod tests` should be at the bottom of the file.
