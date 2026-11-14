## Notes

- Stay on stable Rust: no nightly-only language feature and no nightly-only `rustfmt` or `clippy` option. If the
  project pins a toolchain in `rust-toolchain.toml`, use that one; the pin is a stable release at or above
  1.93, the `rust-version` of the `klibs-rules` crate.
- `cargo clippy --workspace --all-targets -- -D warnings` runs in CI: a finding is fixed, not silenced. Where a
  rule prescribes an exception, it is `#[expect(<lint>, reason = "<why>")]` on the smallest item that needs it,
  never `#[allow(…)]`.
- A finding of the architecture linter, the `klibs-rules` crate, run as `cargo klibs-rules`, is fixed by
  the documents too. Its exception is `#[cfg_attr(klibs_rules, expect(<RuleId>, reason = "<why>"))]` on the
  smallest item that needs it, in three cases only, and the user approves each one before it is written:
  - `Unanalysable`: a limit of the linter, not of the code (a macro it cannot see through);
  - a suspected false positive (the documents allow the flagged code, or every fix they allow is ruled out by
    another rule), reported to the `klibs-rules` repository; the reason names the report;
  - existing code during a rollout (`linter-rollout`) that a document names as staying (existing crate paths and
    names, existing DI wiring, existing listener traits, an old `error.rs` module); the reason names that document
    line.

  `klibs_rules` is the crate name as a `cfg` identifier. No build sets it, so rustc and clippy drop the `expect`
  and only the linter reads it. `[workspace.lints.rust]` declares it, `unexpected_cfgs = { level = "warn",
  check-cfg = ["cfg(klibs_rules)"] }`, or `-D warnings` stops the build with "unexpected `cfg` condition name".
  One reason covers one item: there is no baseline and no reason shared by unrelated items.

  For a finding that has no item (a crate, a directory, a manifest key, a dependency edge), the same exception, in
  the same three cases and with the same approval, sits in the manifest, Kotlin's `Checks(disabled = …,
  allowedDependencies = …)`: `[package.metadata.klibs-rules.checks.disabled.<RuleId>]` (or the workspace table,
  `[workspace.metadata.klibs-rules.checks.disabled.<RuleId>]`) holding `"<subject>" = "<reason>"`, the subject
  being the report's subject column, or `[package.metadata.klibs-rules.checks.allowed-dependencies]` holding
  `"<crate>" = "<reason>"` for an edge.

  ```toml
  # modules/billing/sqlx/Cargo.toml
  [package.metadata.klibs-rules.checks.disabled.UnitReadme]
  "shop-billing-sqlx" = "suspected false positive, reported to klibs-rules as #12"

  [package.metadata.klibs-rules.checks.allowed-dependencies]
  "shop-ledger-sqlx" = "suspected false positive, reported to klibs-rules as #14"
  ```
- Kotlin's note to ignore warnings about experimental features has no Rust counterpart: stable rustc refuses an
  unstable feature with an error (E0554 for `#![feature]`, E0658 for its use), not a warning, and every warning it
  does print is a finding under `-D warnings`.
