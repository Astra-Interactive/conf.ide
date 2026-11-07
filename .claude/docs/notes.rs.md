## Notes

- Stay on stable Rust: no nightly-only language feature and no nightly-only `rustfmt` or `clippy` option. If the
  project pins a toolchain in `rust-toolchain.toml`, use that one.
- `cargo clippy --workspace --all-targets -- -D warnings` runs in CI: a finding is fixed, not silenced. Where a
  rule prescribes an exception, it is `#[expect(<lint>, reason = "<why>")]` on the smallest item that needs it,
  never `#[allow(…)]`.
- Kotlin's note to ignore warnings about experimental features has no Rust counterpart: stable rustc refuses an
  unstable feature with an error (E0554 for `#![feature]`, E0658 for its use), not a warning, and every warning it
  does print is a finding under `-D warnings`.
