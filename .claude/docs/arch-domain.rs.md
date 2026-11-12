## Rust: domain building blocks

How the domain rule is written in Rust. The Kotlin companion is the reference: a line here differs from it only
where Rust cannot say the Kotlin form, and then it gives the Rust reason.

The examples sit in an unsplit sub-context crate, `modules/invoice`, so their items are `pub(crate)`, as Kotlin's
`internal JailInmate` is; in an `api` crate the same items are `pub` (`arch-package.rs.md`, Visibility).

- An entity and a value object are immutable `struct`s holding what the domain rule lists. They derive `Debug`,
  `Clone` and `PartialEq` (Kotlin's generated `toString`, `copy` and `equals`), and also `Eq` and `Hash` when every
  field implements them: `f32` and `f64` implement only `PartialEq` (std, `Eq`). The model file holds the struct,
  its derives, at most one `impl` block, which holds only associated constants and, for a value object with an
  invariant, its `new` and accessors, and the type's trait `impl`s: a conversion (`From`, `TryFrom`), a by-value
  operator of `std::ops` (`Add`, not `AddAssign`), `Display`, what serde needs (`#[serde(try_from = "i64")]` compiles
  only with `TryFrom<i64>`), any trait a library's API requires whose methods take `&self` or `self`. Like Kotlin's
  `override`s in a data class, which the Kotlin checker does not report, they are left to review: whether one holds
  a rule that belongs in `util` is the reviewer's call. Two sit elsewhere, since `model` names no technology or
  framework type: a conversion from or to a technology representation, in the representation's file, and a
  framework's failure trait, in `error` (both below). A rule is a method of an `impl <Type>` block in `util/<type>_ext.rs` of the level that uses it. No method of a model
  type takes `&mut self`, and no code assigns a field of a model value: a state transition takes `self` and
  returns the new value.

  ```rust
  // invoice/model/invoice.rs
  #[derive(Debug, Clone, PartialEq, Eq, Hash)]
  pub(crate) struct Invoice {
      pub(crate) id: InvoiceId,
      pub(crate) total: Money,
      pub(crate) due_at: SystemTime,
      pub(crate) paid_at: Option<SystemTime>,
  }

  // invoice/util/invoice_ext.rs
  impl Invoice {
      pub(crate) fn is_paid(&self) -> bool {
          self.paid_at.is_some()
      }

      pub(crate) fn is_overdue(&self, now: SystemTime) -> bool {
          !self.is_paid() && now > self.due_at
      }

      pub(crate) fn settle(self, now: SystemTime) -> Invoice {
          Invoice {
              paid_at: Some(now),
              ..self
          }
      }
  }
  ```

  An inherent `impl` may sit in any module of the crate that declares the type (Reference, Implementations), so
  the `util` block is called the way a Kotlin extension is, `invoice.is_overdue(now)`, and like an extension it
  cannot read a private field (E0616). When another crate declares the type, the block is the one `impl` of a
  trait `<Type>Ext` declared in the same file: an inherent `impl` of another crate's type does not compile
  (E0116), and `…Ext` is Rust's name for such a trait (RFC 445).

- A typed identifier is a tuple struct over the primitive, `pub(crate) struct InvoiceId(pub(crate) Uuid)`,
  deriving `Debug, Clone, Copy, PartialEq, Eq, Hash`, `Copy` only when the inner type is `Copy` (a `String` inside
  refuses it, E0204). A single-property value object is a tuple struct too.
- A value object with an invariant keeps its fields private: Rust has no read-only field, and only a private
  field stops a struct literal in another module from skipping the check (E0451). Its `new` checks the invariant
  with `assert!` calls and nothing else when a violation is a programmer error, and each field gets an accessor
  named after what it holds. When the input comes from a user, `parse_<type>(raw) -> Result<Type, TypeError>` in
  its `util` returns `Err` before it calls `new`.

  ```rust
  // invoice/model/money.rs
  #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
  pub(crate) struct Money(i64);

  impl Money {
      pub(crate) fn new(cents: i64) -> Self {
          assert!(cents >= 0, "money is never negative, got {cents}");
          Self(cents)
      }

      pub(crate) fn cents(&self) -> i64 {
          self.0
      }

      pub(crate) const ZERO: Money = Money(0);
  }

  // invoice/util/money_parse.rs
  pub(crate) fn parse_money(raw: &str) -> Result<Money, MoneyError> {
      let Ok(cents) = raw.trim().parse::<i64>() else {
          return Err(MoneyError::NotANumber {
              raw: raw.to_owned(),
          });
      };
      if cents < 0 {
          return Err(MoneyError::Negative { cents });
      }
      Ok(Money::new(cents))
  }
  ```

- A sealed hierarchy is one `enum` in one file in `model`: the per-use-case results (`enum PayInvoiceResult`), the
  error families of the error-handling rule, the events of an aggregate. A struct that only its variants carry
  sits in its file.
- A use case is a `struct` named `<Verb><Object>UseCase` in the `usecase` module of its concept
  (`invoice/usecase/pay_invoice_use_case.rs`). Besides `new`, its one public method is `invoke`, `async` when it
  awaits a contract. Kotlin's `operator fun invoke` has no stable Rust form, since implementing `FnOnce` for a
  struct is unstable (E0183, `fn_traits`), so the caller writes `pay_invoice_use_case.invoke(id).await` as Kotlin
  writes `.invoke(…)`. It is constructed by its unit's DI module and takes each contract through `new` as an
  `Arc<dyn Contract>` (`di-manual.rs.md`). It uses no platform crate: the platform is reached through a contract
  of its sub-context.

  ```rust
  // invoice/usecase/pay_invoice_use_case.rs
  pub(crate) struct PayInvoiceUseCase {
      invoice_repository: Arc<dyn InvoiceRepository>,
      clock: Arc<dyn Clock>,
  }

  impl PayInvoiceUseCase {
      pub(crate) fn new(
          invoice_repository: Arc<dyn InvoiceRepository>,
          clock: Arc<dyn Clock>,
      ) -> Self {
          Self {
              invoice_repository,
              clock,
          }
      }

      pub(crate) async fn invoke(&self, id: InvoiceId) -> PayInvoiceResult {
          let invoice = match self.invoice_repository.find_invoice(id).await {
              Ok(Some(invoice)) => invoice,
              Ok(None) => return PayInvoiceResult::NotFound,
              Err(error) => return PayInvoiceResult::Failed(error),
          };
          if invoice.is_paid() {
              return PayInvoiceResult::AlreadyPaid;
          }
          let paid = invoice.settle(self.clock.now());
          match self.invoice_repository.save_invoice(paid.clone()).await {
              Ok(()) => PayInvoiceResult::Paid(paid),
              Err(error) => PayInvoiceResult::Failed(error),
          }
      }
  }
  ```

- A repository, like every contract in `api`, is a trait with the supertraits `Send + Sync`, named
  `<Aggregate>Repository`, in the `api` module of the concept it stores (`invoice/api/invoice_repository.rs`). Its
  methods are `async fn` where they do I/O, and the trait and every `impl` of it carry `#[async_trait]`, from
  async-trait 0.1.92 or later: 0.1.89 and 0.1.91 fail `clippy::double_must_use` on clippy 1.99, and 0.1.90 is not
  on crates.io. A trait with a native `async fn` cannot be a `dyn` type (Reference, Dyn compatibility; E0038 on
  1.93 and 1.99), and the Rust Async Working Group names the `async-trait` crate for dynamic dispatch (Rust blog,
  2023-12-21); `Send + Sync` lets one `Arc<dyn …>` serve several threads (std, `Arc`). Implementations are
  `pub(crate)` structs in the technology module under the same concept (`invoice/file/file_invoice_repository.rs`).
  A `stub` or `memory` implementation another crate uses is `pub`, and so is a fake of the fixture tree that other
  crates' tests use; fakes live in `fake/` as `arch-package.rs.md`, Tests, says, never in a technology module.

  ```rust
  // invoice/api/invoice_repository.rs
  #[async_trait]
  pub(crate) trait InvoiceRepository: Send + Sync {
      async fn find_invoice(&self, id: InvoiceId) -> Result<Option<Invoice>, InvoiceError>;
      async fn save_invoice(&self, invoice: Invoice) -> Result<(), InvoiceError>;
  }
  ```

- An aggregate factory with rules is a free function `create_<aggregate>(…) -> Result<Aggregate, AggregateError>`
  in the aggregate's `util`, never an associated function of the model type. The factory of a type that needs
  arguments known only when it is created is a trait `<Type>Factory: Send + Sync` with one method, `invoke`,
  declared in the file of the type it builds (of the type's trait when it has one) and implemented by a DI module:
  Rust cannot declare a trait inside a type (Reference, Associated items).
- A domain event is a `struct` in `model` named in the past tense (`InvoicePaid`), or a variant of an `enum`
  `<Subject>Event` there. A publisher contract in `api` hands it out as a stream, the standard library having no
  counterpart of Kotlin's `Flow`: `fn events(&self) -> BoxStream<'static, InvoiceEvent>`
  (`futures::stream::BoxStream`). A platform's event type that carries it, declared only for other programs, lives
  in the `event` kind of the platform unit.
- `serde`'s `Serialize` and `Deserialize` derives are allowed on a model type. An ORM or platform crate (`sqlx`,
  `diesel`, a host framework's API crate) is never used in `model`, in a use case or in a domain contract. A
  framework that takes a failure through a trait of its own gets that trait's `impl` in the `error` kind of its
  entry-point unit, so the error type in `model` names nothing of the framework. Which crates count as a platform
  or a framework is the reviewer's call.
- A technology representation (`InvoiceRow`) converts to and from the model at its own edge, by `From` or
  `TryFrom` impls in its own file (API Guidelines C-CONV-TRAITS). When neither type is declared in that crate the
  orphan rule refuses the impl (E0117), and the conversion is a `to_<type>` method of a `<Type>Ext` trait in the
  `util` of the level that uses it.
