## Rust: function paths over trivial closures

A closure whose whole body is one call that receives the closure's parameters unchanged, in the same order, is
written as the path of that function. The path says which function runs and nothing else; the closure adds a
parameter name and a call that carry no information.

```rust
// Bad
let user_ids: Vec<UserId> = ids.into_iter().map(|id| UserId(id)).collect();
let contents: Vec<ItemContent> = items.iter().map(|item| item.to_item_content()).collect();
let names: Vec<&str> = text.lines().map(|line| line.trim()).collect();
let labels: Vec<String> = codes.iter().map(|code| code.to_string()).collect();
let order = parse_order(raw).map_err(|error| PlaceOrderError::Order(error))?;

// Good
let user_ids: Vec<UserId> = ids.into_iter().map(UserId).collect();
let contents: Vec<ItemContent> = items.iter().map(CartItem::to_item_content).collect();
let names: Vec<&str> = text.lines().map(str::trim).collect();
let labels: Vec<String> = codes.iter().map(ToString::to_string).collect();
let order = parse_order(raw).map_err(PlaceOrderError::Order)?;
```

The forms: `function` and `path::to::function` for a free function; the name of a tuple struct or a tuple
variant, which is its constructor (`UserId`, `Some`, `PlaceOrderError::Order`); `Type::method` for a method of the
receiver (`CartItem::to_item_content`, `str::trim`); `Trait::method` for a trait method
(`ToString::to_string`).

When the closure first adapts its parameter with a method and then calls one function, move the adaptation into
the chain and use the path: `.map(|line| parse_order(line.trim()))` becomes `.map(str::trim).map(parse_order)`.
Stop at two steps: a chain that needs a third call to reach a path is less readable than the closure.

The closure stays when a path cannot say the same thing:

- the body reads a field: Rust has no path to a field (`|user| user.name.clone()`);
- the body calls a method of a captured value: Rust has no bound method path (`|offer| selected.push(offer)`);
- the parameter reaches the function only through an auto-borrow or a deref coercion the path does not make
  (`|name: &String| greet(name)` for a `greet(&str)`);
- the parameters are reordered, repeated, or one is dropped;
- the body has more than one call, a condition, a macro, or a second use of the parameter.

A path removes the parameter, so the closure-naming rule has nothing to name: a closure that would only name a
single letter to pass it on is the case for a path.
