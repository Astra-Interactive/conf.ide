Follow the instruction documents this file lists; the paragraph after the section list says when each is read.
All paths are relative to the repository root.

Before choosing project mechanisms, read `AGENTS.project.md` in the current repository/worktree root
if it exists. It is an optional consumer-owned file, not relative to this file's physical symlink target.
Its project-specific conventions specialize the shared defaults; current user instructions take precedence.
Neither document grants tool permissions or overrides the execution environment or secret-handling rules.
An absent project file is not a blocker and is not a request to create one.

Which sections apply:

- **Always**: General, Agents and Code.
- **Kotlin project** (`settings.gradle.kts` or `build.gradle.kts` at the root): Kotlin.
- **Rust project** (`Cargo.toml` at the root): Rust.
- **Both languages in one repository**: Kotlin and Rust.
- **XML files in the task** (`.xml`): XML.

Read the General and Agents documents in full before the first tool call. The Code, Kotlin, Rust and XML
documents load with the first matching file you read or edit (Claude Code serves them as `.claude/rules`,
generated from these lists). Read them yourself only before writing a matching file when no file you read
has loaded them yet. A harness without path rules (Codex) loads none of them: before your first edit of a
matching file, read the documents of that file's sections. These lists stay the index of the documents. A
new document goes into one of them and keeps its group's suffix (`.kt.md`, `.rs.md`).

## General (always)

- [.claude/docs/git-commits.md](.claude/docs/git-commits.md)
- [.claude/docs/secrets.md](.claude/docs/secrets.md)
- [.claude/docs/no-workarounds.md](.claude/docs/no-workarounds.md)
- [.claude/docs/apply-patch.md](.claude/docs/apply-patch.md)

## Agents (always)

- [.claude/docs/subagents.md](.claude/docs/subagents.md)

## Graphify (on demand)

- Read [.claude/docs/graphify-mcp.md](.claude/docs/graphify-mcp.md) when tracing a documented decision to code or preparing an architecture map to share.

## Code (any language, always)

- [.claude/docs/arch-package.md](.claude/docs/arch-package.md)
- [.claude/docs/arch-domain.md](.claude/docs/arch-domain.md)
- [.claude/docs/arch-context.md](.claude/docs/arch-context.md)
- [.claude/docs/codebase-memory.md](.claude/docs/codebase-memory.md)
- [.claude/docs/region.md](.claude/docs/region.md)

## Kotlin (`.kt`, `.kts`)

- [.claude/docs/arch-package.kt.md](.claude/docs/arch-package.kt.md)
- [.claude/docs/arch-domain.kt.md](.claude/docs/arch-domain.kt.md)
- [.claude/docs/clean-code.kt.md](.claude/docs/clean-code.kt.md)
- [.claude/docs/code-ordering.kt.md](.claude/docs/code-ordering.kt.md)
- [.claude/docs/compose.kt.md](.claude/docs/compose.kt.md)
- [.claude/docs/coroutines.kt.md](.claude/docs/coroutines.kt.md)
- [.claude/docs/di-manual.kt.md](.claude/docs/di-manual.kt.md)
- [.claude/docs/di-manual-constructors.kt.md](.claude/docs/di-manual-constructors.kt.md)
- [.claude/docs/error-handling.kt.md](.claude/docs/error-handling.kt.md)
- [.claude/docs/function-reference.kt.md](.claude/docs/function-reference.kt.md)
- [.claude/docs/javadoc.kt.md](.claude/docs/javadoc.kt.md)
- [.claude/docs/kotlin-lsp.kt.md](.claude/docs/kotlin-lsp.kt.md)
- [.claude/docs/ksrc.kt.md](.claude/docs/ksrc.kt.md)
- [.claude/docs/no-callbacks.kt.md](.claude/docs/no-callbacks.kt.md)
- [.claude/docs/no-pair.kt.md](.claude/docs/no-pair.kt.md)
- [.claude/docs/no-print.kt.md](.claude/docs/no-print.kt.md)
- [.claude/docs/notes.kt.md](.claude/docs/notes.kt.md)
- [.claude/docs/testing.kt.md](.claude/docs/testing.kt.md)
- [.claude/docs/testing-no-useless.kt.md](.claude/docs/testing-no-useless.kt.md)
- [.claude/docs/time-api.kt.md](.claude/docs/time-api.kt.md)

## Rust (`.rs`, `Cargo.toml`)

- [.claude/docs/arch-package.rs.md](.claude/docs/arch-package.rs.md)
- [.claude/docs/arch-domain.rs.md](.claude/docs/arch-domain.rs.md)
- [.claude/docs/async.rs.md](.claude/docs/async.rs.md)
- [.claude/docs/clean-code.rs.md](.claude/docs/clean-code.rs.md)
- [.claude/docs/code-ordering.rs.md](.claude/docs/code-ordering.rs.md)
- [.claude/docs/dependency-sources.rs.md](.claude/docs/dependency-sources.rs.md)
- [.claude/docs/di-manual.rs.md](.claude/docs/di-manual.rs.md)
- [.claude/docs/di-manual-constructors.rs.md](.claude/docs/di-manual-constructors.rs.md)
- [.claude/docs/error-handling.rs.md](.claude/docs/error-handling.rs.md)
- [.claude/docs/function-reference.rs.md](.claude/docs/function-reference.rs.md)
- [.claude/docs/no-callbacks.rs.md](.claude/docs/no-callbacks.rs.md)
- [.claude/docs/no-print.rs.md](.claude/docs/no-print.rs.md)
- [.claude/docs/no-tuples.rs.md](.claude/docs/no-tuples.rs.md)
- [.claude/docs/notes.rs.md](.claude/docs/notes.rs.md)
- [.claude/docs/rust-lsp.rs.md](.claude/docs/rust-lsp.rs.md)
- [.claude/docs/rustdoc.rs.md](.claude/docs/rustdoc.rs.md)
- [.claude/docs/struct-default-values.rs.md](.claude/docs/struct-default-values.rs.md)
- [.claude/docs/testing.rs.md](.claude/docs/testing.rs.md)
- [.claude/docs/testing-no-useless.rs.md](.claude/docs/testing-no-useless.rs.md)
- [.claude/docs/time-api.rs.md](.claude/docs/time-api.rs.md)

## XML (`.xml`)

- [.claude/docs/xmlstarlet.md](.claude/docs/xmlstarlet.md)

## Linter-enforced

The linter checks these completely, so no path rule loads them. Read one when you fix a finding of its rule;
the reviewers read the ones of the change's languages.

- [.claude/docs/data-class-default-values.kt.md](.claude/docs/data-class-default-values.kt.md)
- [.claude/docs/imports.kt.md](.claude/docs/imports.kt.md)
- [.claude/docs/no-it.kt.md](.claude/docs/no-it.kt.md)
- [.claude/docs/serial-name.kt.md](.claude/docs/serial-name.kt.md)
- [.claude/docs/closure-naming.rs.md](.claude/docs/closure-naming.rs.md)
- [.claude/docs/imports.rs.md](.claude/docs/imports.rs.md)
