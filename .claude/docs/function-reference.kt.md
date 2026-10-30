## Kotlin: function references over trivial lambdas

A lambda whose whole body is one call that receives the lambda's parameters unchanged, in the same order,
is written as a reference to that function. The reference says which function runs and nothing else; the
lambda adds a parameter name and a call that carry no information.

```kotlin
// Bad
subscription.expirationDate?.time?.let { millis -> Instant.fromEpochMilliseconds(millis) }
ids.map { id -> UserId(id) }
items.map { item -> item.toItemContent() }
users.map { user -> user.name }
lines.mapNotNull { line -> line.toIntOrNull() }
offers.forEach { offer -> repository.save(offer) }

// Good
subscription.expirationDate?.time?.let(Instant::fromEpochMilliseconds)
ids.map(::UserId)
items.map(Cart.Item::toItemContent)
users.map(User::name)
lines.mapNotNull(String::toIntOrNull)
offers.forEach(repository::save)
```

The forms: `::topLevel` and `::Constructor`; `Type::member` for a member, an extension or a property of the
receiver; `Type::companionMember` for a companion function (`Instant::fromEpochMilliseconds`);
`instance::member` for a bound reference (`repository::save`, `viewModel::onPurchase`). A companion member
of a generic class cannot be referenced through the class name (`Result::success` does not compile): import it
from its companion and reference it as `::member` (`import kotlin.Result.Companion.success`,
`onSuccess = ::success`). A reference also replaces a lambda passed as an event handler:
`onClick = viewModel::onPurchase`, not `onClick = { viewModel.onPurchase() }`.

When the lambda first adapts its parameter (`date.time`) and then calls one function, move the adaptation
into the chain and reference the function: `expirationDate?.let { date -> Instant.fromEpochMilliseconds(date.time) }`
becomes `expirationDate?.time?.let(Instant::fromEpochMilliseconds)`. Stop at two steps: a chain that needs
a third `?.` to reach a reference is less readable than the lambda.

The lambda stays when a reference cannot say the same thing:

- the function is `suspend` and the parameter is not: `let`, `map` and the other inline functions accept a
  lambda that calls a `suspend` function, but not a `suspend` function reference (`let(::loadOffer)` does not
  compile inside `suspend` code; `let { placement -> loadOffer(placement) }` does);
- the call relies on a default argument or on a named argument, or an overload makes `::name` ambiguous;
- the parameters are reordered, repeated, or one is dropped;
- the body has more than one call, a condition, or a second use of the parameter.

A reference removes the parameter name, so the `it` rule has nothing to name: a lambda that would only
name `it` to pass it on is the case for a reference.
