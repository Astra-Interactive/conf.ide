## Constructors Dependency Injection Rule

Never instantiate concrete dependencies inside a type's `new`, its other constructors (`with_…`, `from_…`), a
`Default` impl, or its methods. Rust has no default argument; a `Default` impl that builds a dependency is
Kotlin's `= SomeImplementation()` default.

A dependency is a value with behaviour the type calls and a test might replace (a repository, a client, a clock).
The type's own state (a `Mutex<HashMap<…>>`, a channel, a `Vec`) is not one.

Dependencies must be created only at the composition root / DI module, then passed down from parent to child
through `new`.

Bad:

```rust
impl InvoiceReminder {
    pub(crate) fn new(invoice_repository: Arc<dyn InvoiceRepository>) -> Self {
        Self {
            invoice_repository,
            schedule: ReminderSchedule::new(),
            mail_sender: Arc::new(SmtpMailSender::new()),
            clock: Arc::new(SystemClock),
        }
    }
}
```

Good:

```rust
impl InvoiceReminder {
    pub(crate) fn new(
        invoice_repository: Arc<dyn InvoiceRepository>,
        schedule: ReminderSchedule,
        mail_sender: Arc<dyn MailSender>,
        clock: Arc<dyn Clock>,
    ) -> Self {
        Self {
            invoice_repository,
            schedule,
            mail_sender,
            clock,
        }
    }
}
```

When adding a new dependency, update the root wiring instead of calling `SomeImplementation::new()` in the type.

A value the type derives from what it was given, such as `shutdown.child_token()` of the `CancellationToken` it
received, is not a dependency: it is part of the type and stays a field.
