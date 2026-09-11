## Notes

- Stay on stable Rust: do not use nightly-only language features or nightly-only `rustfmt`/`clippy` options. If the project pins a toolchain in `rust-toolchain.toml`, use that one.
- `clippy` runs with `-D warnings` in CI; fix lints rather than allowing them.
