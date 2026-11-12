## Rust: Clean Architecture

You are a senior software engineer. Your task is not only to make the code work, but to make it clean, maintainable, readable, extensible, and production-ready.

Follow the principles from **Clean Code by Robert C. Martin** and apply appropriate **software design patterns** where they improve the solution.

Core requirements. A checker checks what a rule states as a fixed name, number or shape; everything else in
these rules is the reviewer's call.

### 1. Write clean, readable code

* Use meaningful names for variables, functions, types, traits, files, and modules.
* Avoid vague names like `data`, `temp`, `foo`, `manager`, `handler`, unless the meaning is obvious (the
  reviewer's call). A kind module that the package-layout rule names is not a vague name.
* A function is named with a verb that says what happens; one that returns a value is never a bare noun
  (`card_segments()`, `featured_shortcuts()`, `title_style()` mislead) and never starts with `get_`. These keep
  their names: a constructor (`new`, `with_<detail>`, `from_<source>`); the `invoke` of a use case or a factory
  (the domain rule); a method of an `impl Trait for` block (the trait names it); a method whose body only returns
  a field, named after that field (`fn total(&self) -> Money`); `get`, `get_mut`, `get_unchecked` and
  `get_unchecked_mut` as the lookup of a collection type; a DI `provide_…`; a test, named by the testing rule.
  The usual verbs; another verb is fine when it says what happens as plainly:

  | Verb | When | Example |
  |---|---|---|
  | `select` | one of fixed values, chosen by a condition | `select_card_segments(stage)` |
  | `resolve` | a value from several sources or by precedence | `resolve_title_style(size)` |
  | `build` | a new value or collection assembled from parts | `build_shortcuts()` |
  | `create` | an aggregate factory with a rule, returning `Result` | `create_jail(name, location)` |
  | `compute` | a number or geometry | `compute_opacity(distance)` |
  | `format` | a value turned into text for display | `format_price(plan)` |
  | `parse` | text turned into a value, returning `Result` | `parse_order(raw)` |
  | `find` | a lookup that may return `None` | `find_plan(id)` |
  | `load` / `fetch` | a read from storage / from the network | `load_offer()`, `fetch_exchange_rate()` |
  | `save` / `send` / `notify` | a write, a dispatch | `notify_purchase_failed()` |
  | `is` / `has` / `can` / `should` | a `bool` predicate | `is_sentence_over(now)`, `can_read(user)` |
  | `to_<type>` | a conversion that copies from `&self` | `plan.to_plan_content()` |
  | `into_<type>` | a conversion that consumes `self` | `order.into_receipt()` |
  | `as_<type>` | a view of `&self`, no copy | `name.as_str()` |
  | `on_<event>` | a handler of a user action, one per action | `on_purchase()` |
  | `update_<thing>` | a state transition | `update_content(content)` |

  Never `map` in a name (`to_content`, not `map_to_content`: `map` is the word of `Option`, `Result` and
  iterators), never `make`, `do`, `handle` or `process`. A banned verb is the first word of a function name
  (`get_user`, `map_to_content`, `handle_click`, `do_work`); the same letters later in the name are not banned.
  A checker enforces only these bans; whether another verb says what happens as plainly is the reviewer's call.
* Keep functions small and focused.
* Each function should do one thing.
* Avoid deeply nested logic. "Small" and "deeply nested" are the project's clippy thresholds, which its
  `clippy.toml` sets: `too-many-lines-threshold = 60` and `excessive-nesting-threshold = 5`, unless the project
  chose other values; `[workspace.lints.clippy]` switches `too_many_lines` on. Both are written out because
  clippy's own defaults differ: 100 lines with `too_many_lines` off, and no nesting check. Clippy counts the
  body's lines of code, and it counts an `impl` block and the function body as levels, so 5 leaves three nested
  blocks inside a method.
* Prefer early returns and guard clauses: `?`, `let … else { return …; }` and `if … { return …; }`.
* Avoid duplicated code.
* Before writing a helper, look for one that exists in the project, in `std` or in a crate the project already
  depends on, and use it: `Option::is_some_and`, `Result::inspect_err`, `Iterator::partition`. A helper that
  duplicates one that exists is dead weight.
* New code has no dead code, unused variables or unnecessary comments; in an old file they are removed only in
  a refactoring the user asked for, never by a task that plugs new code in.
* No `Helper`, `Util` or `Manager` types: a type with behaviour has a role, and the role names it and its module.
* A file holds one type family: an enum with the payload structs only its variants carry, a struct with the
  data types only its fields use. The Rust package-layout rule says what goes in one file.

### 2. Follow SOLID principles

* Single Responsibility Principle: each type or module should have one clear reason to change.
* Open/Closed Principle: code should be extendable without modifying existing logic too much.
* Liskov Substitution Principle: every implementation of a trait should be safely replaceable by any other.
* Interface Segregation Principle: avoid large traits with unrelated methods.
* Dependency Inversion Principle: depend on traits, not concrete implementations. A trait exists on the four triggers of the package-layout rule: another unit calls it, two or more implementations exist or one is known to come, an inner part declares what it needs from an outer one, or a test must replace a contract over I/O or the platform with a fake.

### 3. Use design patterns when appropriate

Use design patterns only when they make the code simpler, cleaner, or easier to extend. Do not over-engineer.

Consider patterns such as:

* Strategy Pattern for interchangeable algorithms or behaviors: one trait, one implementation per strategy.
* Factory Pattern only as the domain rule allows it: a function that creates an aggregate under a rule, or the factory of an object that needs arguments known only when it is created; dependencies are constructed at the composition root.
* Builder Pattern for constructing complex objects step by step.
* Observer/Event Pattern for event-driven systems.
* Repository Pattern for data access abstraction.
* Adapter Pattern for integrating external APIs or incompatible interfaces.
* Decorator Pattern for adding behavior without modifying existing types: a type that implements the same trait and wraps another implementation.
* Command Pattern for actions, tasks, undo/redo, or queued operations.
* Dependency Injection for testability and decoupling.

Before using a pattern, briefly explain why it fits the problem.

### 4. Separate responsibilities

Keep each responsibility in its own type and each type in the kind module of its concept: domain contracts in `api`, data in `model`, operations in `usecase`, the rules of a model in `util`, wiring in `di`, implementations where the package-layout rule places them. Interface exceptions, including framework registration traits beside their mechanism, follow `arch-package.md`. The package-layout rule and skill decide the modules and when a sub-context gets its own crate.

Do not mix unrelated responsibilities in one type or function.

### 5. Make the code testable

* Avoid hard-coded dependencies.
* Inject dependencies where possible.
* Keep pure logic separate from I/O.
* Make functions deterministic when practical.
* Cover new code with tests as the testing rule says.
* Cover important edge cases.

### 6. Handle errors properly

* Do not ignore errors.
* Use clear error messages.
* Validate inputs.
* Fail fast when invalid state is detected.
* Avoid swallowing errors silently.

### 7. Prefer clarity over cleverness

* Do not write overly complex one-liners.
* Line breaks belong to `cargo fmt`: where a body, an initializer, an argument list or a long expression breaks
  is what rustfmt prints by the Rust Style Guide, and that output stays. The rules below change the code, never
  rustfmt's layout of it.
* A closure or `async` block whose whole body is one `if` without `else` around two or more statements is a
  guard with an early `return`, in a spawned task, `for_each` and an event handler alike. An `if` around one
  statement stays as it is: the guard would only add lines.

  ```rust
  // Bad
  self.task_scope.spawn(async move {
      if is_visible {
          tokio::time::sleep(AUTO_HIDE_DELAY).await;
          banner.hide();
      }
  });

  // Good
  self.task_scope.spawn(async move {
      if !is_visible {
          return;
      }
      tokio::time::sleep(AUTO_HIDE_DELAY).await;
      banner.hide();
  });
  ```

* One arithmetic operator (`+`, `-`, `*`, `/`, `%`) directly before a trailing method call (`.round()`,
  `.max(…)`, `.clamp(…)`) is written as its `std::ops` method (`add`, `sub`, `mul`, `div`, `rem`), so the chain
  reads left to right without parentheses. The prelude does not bring these traits: import the one you call
  (`use std::ops::Mul;`). Two or more operators before a trailing call: a named `let` first, then the call;
  `a.mul(b).add(c)` is never written. An expression with no trailing call keeps its operators
  (`subtotal * (1.0 + tax_rate)`).

  ```rust
  // Bad
  let line_height = (font_size * line_height_scale).round();

  // Good
  let line_height = font_size.mul(line_height_scale).round();
  ```

* A condition that rustfmt breaks over several lines is split instead, in this order:
  1. a guard (`let … else { return …; }`, `if … { return …; }`) for a clause that a later one depends on (a
     pattern that binds a value, a check before a field is read), and for a clause that is costly;
  2. a named `let` per remaining clause, named for what it means, so that the condition itself reads as a
     sentence.

  When the named values still do not fit on one line, rustfmt breaks the condition before each `&&` or `||`,
  and that layout stays: `bool` has no `and` or `or` method to chain.

  ```rust
  // Bad
  if let CheckoutState::Content(content) = &current
      && content.stage == CheckoutStage::Payment
      && !content.is_busy
      && content.cart.expires_at > now
  {
      return CheckoutState::Content(CheckoutContent {
          is_busy: true,
          ..content.clone()
      });
  }
  current

  // Good
  let CheckoutState::Content(content) = &current else {
      return current;
  };
  let is_payment_stage = content.stage == CheckoutStage::Payment;
  let is_idle = !content.is_busy;
  let is_cart_alive = content.cart.expires_at > now;
  if is_payment_stage && is_idle && is_cart_alive {
      return CheckoutState::Content(CheckoutContent {
          is_busy: true,
          ..content.clone()
      });
  }
  current
  ```

* `=` never ends a line. The initializer of a `let`, a `const` or a `static`, and the type of a type alias,
  start on the line of their `=`, in an `impl` or a trait too (`const LIMIT: …`, `type Output = …;`), and a type
  alias is one line, from `type` to `;`. A `where` clause is the exception: rustfmt always puts it, and then the
  `=`, on lines of their own (`type Item<'a>`, `= &'a str`, `where`, `Self: 'a;`), and the type after `=` is still
  one line. Kotlin keeps such a declaration by wrapping inside its
  initializer; rustfmt does not keep a layout written by hand (a `.map_err(…)` moved to its own line goes back after
  `=`), so when rustfmt breaks a declaration after `=`, or inside the type of an alias, the code is shortened
  instead:
  1. a name that repeats its context, or a call that changes nothing, is shortened or dropped;
  2. a part is named on its own: the receiver of a call or one of its arguments as a `let` before it (a `const` for
     a constant), a generic type argument as an alias beside it, a long path as a `use` import.

  ```rust
  // Bad
  let serialized_invoice =
      serde_json::to_string(&reminder_invoice).map_err(|source| InvoiceError::Serialize {
          id: reminder_invoice.id,
          source: Box::new(source),
      })?;

  // Good
  let serialization = serde_json::to_string(&reminder_invoice);
  let serialized_invoice = serialization.map_err(|source| InvoiceError::Serialize {
      id: reminder_invoice.id,
      source: Box::new(source),
  })?;
  ```

  ```rust
  // Bad
  type ReminderGate =
      FeatureGate<InvoiceReminderModule, ConfigurationFlagReader<InvoiceReminderConfiguration>>;

  // Good
  type ReminderFlagReader = ConfigurationFlagReader<InvoiceReminderConfiguration>;
  type ReminderGate = FeatureGate<InvoiceReminderModule, ReminderFlagReader>;
  ```

* Kotlin's `.invoke()` rule, which shows that a value is called rather than a declared function, has no Rust
  form to add: a use case or a factory is already called through its `invoke` method (the domain rule), and a
  closure held in a field can only be called as `(self.refresh)()`, whose parentheses already show a value being
  called. `Fn::call`, the counterpart of `.invoke()` on a closure, is unstable (`fn_traits`).

* Do not use advanced language features (macros, complex trait bounds, `unsafe`) unless they improve readability or are genuinely required.
* Code should be understandable by another developer without needing a long explanation.

### 8. Comments and documentation

* Do not comment obvious code.
* Use comments only to explain “why”, not “what”.
* The public API of a published library crate is documented by the rustdoc rule; application code carries no doc comment beyond the rustdoc rule's three exceptions.

### 9. Refactor before final answer

Before providing the final code, review it and improve:

* Naming
* Duplication
* Function size
* Type and trait responsibilities
* Coupling
* Testability
* Error handling
* Pattern usage
* File and module organization: answer the package-layout skill's checklist

### Important:

Do not produce quick-and-dirty code unless explicitly asked. Treat every coding task as production-quality software design. Production quality includes the right amount of structure: the modules, layers, traits and crates the package-layout rules call for, and no more.
