## Code documentation (rustdoc)

This is a Rust project. Documentation is written as rustdoc comments: `///` on items, `//!` at the top of a module or crate. The core principle: **a comment exists only if it adds information not already present in the signature**. If the signature says everything on its own — no comment at all.

This document covers only *how to write* a doc comment. It does not decide whether a function should panic or return `Result` — that is governed by the error-handling rule. `# Panics` is documented whenever the function in question actually panics: an indexing helper, an invariant check, a library API. The examples below are generic API signatures, not templates for domain code.

### Mandatory self-check before writing

Before writing each doc element, ask yourself the question and write the element only if the answer is "yes":

| Element | Question to ask yourself |
|---|---|
| Summary | "Will the reader learn anything from the first sentence that isn't already in the item name and types?" |
| Parameter description | "Could a reader fail to understand why this parameter exists, what its constraints are, or its non-obvious semantics?" |
| Return description | "Is it non-obvious from the name and type what exactly is returned (especially in edge cases: `None`, empty `Vec`, `0`)?" |
| `# Errors` | "Does the function return `Result`, and is it not obvious from the error type's variants when each one is produced?" |
| `# Panics` | "Can the function panic on some input or state the caller controls?" |
| `# Safety` | "Is the function `unsafe`?" (then the section is mandatory: state every invariant the caller must uphold) |
| `# Examples` | "Is the usage so non-obvious that omitting an example would lead to mistakes?" |

If the answer is "no" — the element is **not written**. A partially documented function (only `# Errors`, no summary) is normal and correct.

`# Errors` and `# Panics` are the sections `clippy::missing_errors_doc` and `clippy::missing_panics_doc` expect. Write them as sections, not as free text, so the lints and the reader find them.

### What to write

- The first line — the essence in one sentence. rustdoc shows it alone in item lists, so it must stand on its own. Beyond that — only the non-obvious: contract, side effects, invariants, thread safety, units of measurement, behavior on empty values.
- **Why**, not **what**. The code shows "what"; the comment explains "why" and "under which conditions".
- Units and ranges always explicit: `timeout_ms`, "in the range 0.0..=1.0", "UTC".
- Parameters have no dedicated tag in rustdoc. Describe a parameter in prose only when it has semantics or constraints the type does not express; never list all parameters mechanically.
- Link to other items with intra-doc links: `[`OrderError`]`, `[`Self::place_order`]`. Never spell a type name in backticks when a link is possible.
- An `# Examples` block is a doctest: it compiles and runs under `cargo test`. Keep it minimal and make it pass.
- Module-level `//!` docs explain what the module is for and how its items fit together, not a list of items — rustdoc already generates that.

### What is forbidden

- Filler and signature restatement: "This function is responsible for...", "This method allows you to...", "Returns the result of the operation".
- A parameter description that restates the name: "`user_id` — the identifier of the user".
- "Returns the returned value", "Returns the result".
- Comments on trivial getters, structs with self-explanatory fields, or trait impls that don't change the trait's contract.
- Summaries longer than 3–4 sentences. If it doesn't fit — that's a signal the function does too much, not that a longer comment is needed.
- HTML tags (`<p>`, `<code>`). Use Markdown and intra-doc links.
- `#[doc(hidden)]` or `#[allow(missing_docs)]` to silence a lint instead of deciding whether the comment is needed.

### Examples

**Bad** (verbose, zero information):

```rust
/// This function is intended for retrieving a user by their identifier.
/// The function takes a user identifier and returns the user.
///
/// `user_id` — the identifier of the user.
///
/// Returns the user.
pub fn find_user(&self, user_id: UserId) -> Result<User, UserError>
```

**Good** (only what the signature doesn't say; the error type has several variants, so the one thing worth writing down is which of them this function produces and when):

```rust
/// # Errors
///
/// Returns [`UserError::NotFound`] for a deleted user as well as for an unknown id.
pub fn find_user(&self, user_id: UserId) -> Result<User, UserError>
```

**Bad**:

```rust
/// Function for calculating a discount. Takes a price and a rate and returns the discount.
pub fn discount(price: Money, rate: f64) -> Money
```

**Good** (semantics and constraints not expressed by the types):

```rust
/// Calculates the discount amount, excluding promotional items.
///
/// `rate` is a fraction in the range `0.0..=1.0`, not a percentage. The result is rounded to cents
/// using half-up rounding.
///
/// # Panics
///
/// Panics if `rate` is outside `0.0..=1.0`; validate the rate before calling.
pub fn discount(price: Money, rate: f64) -> Money
```

**Good** (`unsafe` always gets a `# Safety` section, and nothing else is needed here):

```rust
/// # Safety
///
/// `index` must be less than `self.len()`; the check is skipped.
pub unsafe fn get_unchecked(&self, index: usize) -> &Order
```

**Good** (no comment, because none is needed):

```rust
pub fn is_empty(&self) -> bool {
    self.items.is_empty()
}
```

### Final review

After writing a doc comment, reread it and delete every line for which you cannot answer "yes" to: "Will this line save the reader a trip into the function body or a debugging session?"
