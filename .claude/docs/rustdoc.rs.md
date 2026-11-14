## Code documentation (rustdoc)

This is a Rust project. Documentation is written as rustdoc comments: `///` on an item, `//!` at the top of a module or crate. The core principle: **a comment exists only if it adds information not already present in the signature**. If the signature says everything on its own — no comment at all.

This document says when a doc comment is written and how. It does not decide whether a function should panic or return `Result` — that is governed by the error-handling rules. `# Panics` is documented when a function of a published library panics on input or state its caller controls (the self-check below). The examples below are generic API signatures, not templates for domain code.

### Application code: no doc comments

In a plugin, an application or a service the code is understandable without doc comments, and none is written. There are three exceptions, each a line that says what the code cannot:

- the failure case of a contract (`# Errors` with "Returns [`DictionaryError::NotFound`] when no dictionary has this id");
- a reason that points outside the code (a platform quirk, a workaround for a bug in a crate); whether a reason points outside the code is the reviewer's call;
- the safety contract of `unsafe`: an `unsafe fn` or `unsafe trait` carries `# Safety` with every invariant its caller must uphold, and every `unsafe` block a `// SAFETY:` comment that says why those invariants hold. Breaking them is undefined behaviour that no type and no test shows.

A doc comment that says what an item does, why a module exists, or repeats a rule the body shows is not written; in an old file it is removed only in a refactoring the user asked for, never by a task that plugs new code in.

```rust
// Deleted: the name says it, and the body shows the rule
/// Exposes the auth repositories so the application and tests obtain them
/// through the module instead of constructing the implementations directly.
pub(crate) struct AuthModule {
    // …
}

// Kept: the signature cannot say which variant comes back when
/// # Errors
///
/// Returns [`DictionaryError::NotFound`] when no dictionary has this id.
fn delete_dictionary(&self, id: DictionaryId, user: &User) -> Result<(), DictionaryError>;
```

The rest of this rule, the self-check table included, applies to published library crates, the ones whose manifest declares a `version` to publish.

### Mandatory self-check before writing

Before writing each doc element, ask yourself the question and write the element only if the answer is "yes":

| Element | Question to ask yourself |
|---|---|
| Summary | "Will the reader learn anything from the first sentence that isn't already in the item name and types?" |
| Parameter description | "Could a reader fail to understand why this parameter exists, what its constraints are, or its non-obvious semantics?" |
| Return description | "Is it non-obvious from the name and type what exactly is returned (especially in edge cases: `None`, an empty `Vec`, `0`)?" |
| `# Errors` | "Does the function return `Result`, and is it not obvious from the error type's variants when each one is produced?" |
| `# Panics` | "Can the function panic on input or state its caller controls?" |
| `# Examples` | "Is the usage so non-obvious that omitting an example would lead to mistakes?" |

If the answer is "no" — the element is **not written**. A partially documented function (only `# Errors`, no summary) is normal and correct. `# Safety` is not in the table: it is always written, as in application code.

### What to write

- The first sentence — the essence in one line. rustdoc shows it alone in item lists, so it stands on its own. Beyond that — only the non-obvious: contract, side effects, invariants, thread safety, units of measurement, behavior on empty values.
- **Why**, not **what**. The code shows "what"; the comment explains "why" and "under which conditions".
- Units and ranges always explicit: `distance_meters`, "in the range `0.0..=1.0`", "UTC"; a time value carries its unit in its type (the time rule).
- rustdoc has no parameter tag. A parameter is described in prose only when it has semantics or constraints its type does not express, never one line per parameter.
- `# Errors`, `# Panics`, `# Safety` and `# Examples` are headed sections, not free text.
- Items are linked with intra-doc links (`[`OrderError`]`, `[`Self::place_order`]`), never named in plain backticks where a link resolves.
- An `# Examples` block is a doctest: `cargo test` compiles and runs it, so it is minimal and passes.
- A `//!` comment says what the module or crate is for, not which items it holds: rustdoc lists them.

### What is forbidden

- Filler and signature restatement: "This function is responsible for...", "This method allows you to...", "Returns the result of the operation".
- A parameter description that restates the name: "`user_id` — the identifier of the user".
- "Returns the returned value", "Returns the result".
- Comments on trivial getters, structs with self-explanatory fields, or trait impls that don't change the trait's contract.
- Summaries longer than 3–4 sentences. If it doesn't fit — that's a signal the function does too much, not that a longer comment is needed.
- HTML tags (`<p>`, `<code>`, `<br>`). Use Markdown and intra-doc links.
- `#[doc(hidden)]` anywhere but on an item one crate of the library needs from another and no consumer may use
  (`arch-package.rs.md`, Visibility): it never keeps an item out of the documentation to save a doc comment.

### Examples

**Bad** (verbose, zero information):

```rust
/// This function is intended for loading a user by their identifier.
/// The function takes a user identifier and returns the user.
///
/// `user_id` — the identifier of the user.
///
/// Returns the user.
pub fn load_user(&self, user_id: UserId) -> Result<User, UserError>
```

**Good** (only what the signature doesn't say: which variant comes back, documented only when the error type does not make it obvious):

```rust
/// # Errors
///
/// Returns [`UserError::NotFound`] for a deleted user as well as for an unknown id.
pub fn load_user(&self, user_id: UserId) -> Result<User, UserError>
```

**Bad**:

```rust
/// Method for computing a discount. Takes a rate and returns the discount.
pub fn compute_discount(&self, rate: f64) -> Money
```

**Good** (semantics and constraints not expressed by the types):

```rust
/// Computes the discount amount, excluding promotional items.
///
/// `rate` is a fraction in the range `0.0..=1.0`, not a percentage. The amount is rounded to cents,
/// half up.
///
/// # Panics
///
/// Panics if `rate` is outside `0.0..=1.0`.
pub fn compute_discount(&self, rate: f64) -> Money
```

**Good** (`unsafe` always gets `# Safety`, and nothing else is needed here):

```rust
/// # Safety
///
/// `index` is less than `self.len()`; the bounds check is skipped.
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
