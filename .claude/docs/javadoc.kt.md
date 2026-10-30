## Code documentation (KDoc)

This is a Kotlin project. Documentation is written in KDoc format. The core principle: **a comment exists only if it adds information not already present in the signature**. If the signature says everything on its own — no comment at all.

This document says when a KDoc is written and how. It does not decide whether a function should throw or return `Result` — that is governed by the error-handling rules. `@throws` is documented when a function of a published library throws an exception its caller must handle (the self-check below). The examples below are generic API signatures, not templates for domain code.

### Application code: no KDoc

In a plugin, an application or a service the code is understandable without KDoc, and KDoc is not written. There are two exceptions, each a line that says what the code cannot: the failure case of a contract (`@return failure with [DictionaryError.NotFound] when no dictionary has this id`) and a reason that points outside the code (a platform quirk, a workaround for a bug in a library); whether a reason points outside the code is the reviewer's call. A KDoc that says what a declaration does, why a module exists, or repeats a rule the body shows is not written; in an old file it is removed only in a refactoring the user asked for, never by a task that plugs new code in.

```kotlin
// Deleted: the name says it, and the body shows the rule
/**
 * Exposes the firebase auth repositories so the application and tests obtain them
 * through the module instead of constructing the implementations directly.
 */
interface ApiFirebaseModule

// Kept: the signature cannot say which failure comes back
/**
 * @return failure with [DictionaryError.NotFound] when no dictionary has this id
 */
suspend fun deleteDictionary(id: DictionaryId, user: User): Result<Unit>
```

The rest of this rule, the self-check table included, applies to published library units, the ones with `explicitApi()` on.

### Mandatory self-check before writing

Before writing each KDoc element, ask yourself the question and write the element only if the answer is "yes":

| Element | Question to ask yourself |
|---|---|
| Summary | "Will the reader learn anything from the first sentence that isn't already in the function name and types?" |
| `@param` | "Could a reader fail to understand why this parameter exists, what its constraints are, or its non-obvious semantics?" |
| `@return` | "Is it non-obvious from the name and type what exactly is returned (especially in edge cases: null, empty collection, -1)?" |
| `@throws` | "Does the function throw an exception the caller is required to handle or account for?" |
| `@sample` / example | "Is the usage so non-obvious that omitting an example would lead to mistakes?" |

If the answer is "no" — the element is **not written**. A partially documented function (only `@throws`, no summary and no `@param`) is normal and correct.

### What to write

- The first sentence — the essence in one line. Beyond that — only the non-obvious: contract, side effects, invariants, thread safety, units of measurement, behavior on null/empty values.
- **Why**, not **what**. The code shows "what"; the comment explains "why" and "under which conditions".
- Units and ranges always explicit: `distanceMeters`, "in the range 0..1", "UTC"; a time value carries its
  unit in its type (the time rule).
- `@param` describes semantics and constraints, never a restatement of the name.

### What is forbidden

- Filler and signature restatement: "This method is responsible for...", "This function allows you to...", "Returns the result of the operation".
- `@param userId the identifier of the user` (restates the name — delete it).
- `@return the returned value`, `@return the result`.
- Comments on trivial getters, data classes with self-explanatory fields, or overrides that don't change the contract.
- Summaries longer than 3–4 sentences. If it doesn't fit — that's a signal the function does too much, not that a longer comment is needed.
- Javadoc-style HTML tags (`<p>`, `<code>`). In KDoc use Markdown and `[ClassName]`-style links.

### Examples

**Bad** (verbose, zero information):

```kotlin
/**
 * This method is intended for retrieving a user by their identifier.
 * The method takes a user identifier and returns the user object.
 *
 * @param userId the identifier of the user
 * @return the user object
 */
fun loadUser(userId: Long): Result<User>
```

**Good** (only what the signature doesn't say: which failure comes back, documented only when the name and type do not make it obvious):

```kotlin
/**
 * @return failure with [UserNotFoundError] for a deleted user as well as for an unknown id
 */
fun loadUser(userId: Long): Result<User>
```

**Bad**:

```kotlin
/**
 * Function for computing a discount. Takes a price and a rate and returns the discount.
 */
fun computeDiscount(price: BigDecimal, rate: Double): BigDecimal
```

**Good** (semantics and constraints not expressed by the types):

```kotlin
/**
 * Computes the discount amount, excluding promotional items.
 *
 * @param rate discount as a fraction in the range 0.0..1.0, not a percentage
 * @return amount rounded to cents using HALF_UP
 * @throws IllegalArgumentException if rate is outside 0.0..1.0
 */
fun computeDiscount(price: BigDecimal, rate: Double): BigDecimal
```

**Good** (no comment, because none is needed):

```kotlin
fun isEmpty(): Boolean = items.isEmpty()
```

### Final review

After writing a KDoc, reread it and delete every line for which you cannot answer "yes" to: "Will this line save the reader a trip into the function body or a debugging session?"