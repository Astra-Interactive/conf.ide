Use this index to load the rules for your role and the mechanisms the task changes.
All paths are relative to the repository root.

Before choosing project mechanisms, read `AGENTS.project.md` in the current repository/worktree root
if it exists. It is an optional consumer-owned file, not relative to this file's physical symlink target.
Its project-specific conventions specialize the shared defaults; current user instructions take precedence.
Neither document grants tool permissions or overrides the execution environment or secret-handling rules.
An absent project file is not a blocker and is not a request to create one.

On first use, read the General documents that govern your actions and the Agents document for delegation.
Before a source edit or review, load its language's clean-code and code-ordering rules, then the entries
whose conditions match the changed mechanisms. Follow a loaded rule's references when they govern a decision
you are making. An unchanged adjacent mechanism alone does not require its documents.

The coordinator passes the goal, acceptance conditions, paths, revision and applicable rule references.
Each agent reads those sources once. On resume, load changed instructions and newly affected mechanisms.
Use the existing source and evidence when their revision and scope still match.

Claude Code receives path-conditioned pointers generated from this index. Codex reads the applicable entries
here directly. Both load the same rule sources on demand. Keep each new document in its section with a
condition for loading it and its group's suffix (`.kt.md`, `.rs.md`).

## General

- [.claude/docs/git-commits.md](.claude/docs/git-commits.md) — changing files or publishing work.
- [.claude/docs/secrets.md](.claude/docs/secrets.md) — all work.
- [.claude/docs/no-workarounds.md](.claude/docs/no-workarounds.md) — diagnosing or correcting failures.
- [.claude/docs/apply-patch.md](.claude/docs/apply-patch.md) — editing files.

## Agents (always)

- [.claude/docs/subagents.md](.claude/docs/subagents.md)

## Graphify (on demand)

- Read [.claude/docs/graphify-mcp.md](.claude/docs/graphify-mcp.md) when tracing a documented decision to code or preparing an architecture map to share.

## Code

- [.claude/docs/arch-package.md](.claude/docs/arch-package.md) — adding, moving or deleting source files, packages or units.
- [.claude/docs/arch-domain.md](.claude/docs/arch-domain.md) — changing responsibilities, models, use cases or storage.
- [.claude/docs/arch-context.md](.claude/docs/arch-context.md) — changing dependencies, APIs or cross-unit data flow.
- [.claude/docs/codebase-memory.md](.claude/docs/codebase-memory.md) — structural exploration and impact analysis.
- [.claude/docs/region.md](.claude/docs/region.md) — changing source organization within a file.

## Kotlin (`.kt`, `.kts`)

- [.claude/docs/arch-package.kt.md](.claude/docs/arch-package.kt.md) — adding, moving or deleting Kotlin files, packages or modules.
- [.claude/docs/arch-domain.kt.md](.claude/docs/arch-domain.kt.md) — changing model, use-case or storage responsibilities.
- [.claude/docs/clean-code.kt.md](.claude/docs/clean-code.kt.md) — every Kotlin edit or review.
- [.claude/docs/code-ordering.kt.md](.claude/docs/code-ordering.kt.md) — every Kotlin edit or review.
- [.claude/docs/compose.kt.md](.claude/docs/compose.kt.md) — changing Compose code or resources it displays.
- [.claude/docs/coroutines.kt.md](.claude/docs/coroutines.kt.md) — changing asynchronous work, flow or coroutine lifetime.
- [.claude/docs/di-manual.kt.md](.claude/docs/di-manual.kt.md) — changing dependency assembly or ownership.
- [.claude/docs/di-manual-constructors.kt.md](.claude/docs/di-manual-constructors.kt.md) — changing dependency constructors.
- [.claude/docs/error-handling.kt.md](.claude/docs/error-handling.kt.md) — changing fallible operations or failure handling.
- [.claude/docs/function-reference.kt.md](.claude/docs/function-reference.kt.md) — changing function references or lambdas.
- [.claude/docs/javadoc.kt.md](.claude/docs/javadoc.kt.md) — changing public contracts or documentation.
- [.claude/docs/kotlin-lsp.kt.md](.claude/docs/kotlin-lsp.kt.md) — semantic navigation or diagnostics.
- [.claude/docs/ksrc.kt.md](.claude/docs/ksrc.kt.md) — inspecting dependency APIs or sources.
- [.claude/docs/no-callbacks.kt.md](.claude/docs/no-callbacks.kt.md) — changing callbacks or event delivery.
- [.claude/docs/no-pair.kt.md](.claude/docs/no-pair.kt.md) — changing returned or stored tuples.
- [.claude/docs/no-print.kt.md](.claude/docs/no-print.kt.md) — changing diagnostic output or logging.
- [.claude/docs/notes.kt.md](.claude/docs/notes.kt.md) — checking project exceptions for an affected rule.
- [.claude/docs/testing.kt.md](.claude/docs/testing.kt.md) — changing tests or fixtures.
- [.claude/docs/testing-no-useless.kt.md](.claude/docs/testing-no-useless.kt.md) — deciding which regression tests are needed.
- [.claude/docs/time-api.kt.md](.claude/docs/time-api.kt.md) — changing clocks, durations or dates.

## Rust (`.rs`, `Cargo.toml`)

- [.claude/docs/arch-package.rs.md](.claude/docs/arch-package.rs.md) — adding, moving or deleting Rust files, packages or crates.
- [.claude/docs/arch-domain.rs.md](.claude/docs/arch-domain.rs.md) — changing model, use-case or storage responsibilities.
- [.claude/docs/async.rs.md](.claude/docs/async.rs.md) — changing asynchronous work or task lifetime.
- [.claude/docs/clean-code.rs.md](.claude/docs/clean-code.rs.md) — every Rust edit or review.
- [.claude/docs/code-ordering.rs.md](.claude/docs/code-ordering.rs.md) — every Rust edit or review.
- [.claude/docs/dependency-sources.rs.md](.claude/docs/dependency-sources.rs.md) — inspecting dependency APIs or sources.
- [.claude/docs/di-manual.rs.md](.claude/docs/di-manual.rs.md) — changing dependency assembly or ownership.
- [.claude/docs/di-manual-constructors.rs.md](.claude/docs/di-manual-constructors.rs.md) — changing dependency constructors.
- [.claude/docs/error-handling.rs.md](.claude/docs/error-handling.rs.md) — changing fallible operations or failure handling.
- [.claude/docs/function-reference.rs.md](.claude/docs/function-reference.rs.md) — changing function references or closures.
- [.claude/docs/no-callbacks.rs.md](.claude/docs/no-callbacks.rs.md) — changing callbacks or event delivery.
- [.claude/docs/no-print.rs.md](.claude/docs/no-print.rs.md) — changing diagnostic output or logging.
- [.claude/docs/no-tuples.rs.md](.claude/docs/no-tuples.rs.md) — changing returned or stored tuples.
- [.claude/docs/notes.rs.md](.claude/docs/notes.rs.md) — checking project exceptions for an affected rule.
- [.claude/docs/rust-lsp.rs.md](.claude/docs/rust-lsp.rs.md) — semantic navigation or diagnostics.
- [.claude/docs/rustdoc.rs.md](.claude/docs/rustdoc.rs.md) — changing public contracts or documentation.
- [.claude/docs/struct-default-values.rs.md](.claude/docs/struct-default-values.rs.md) — changing struct initialization or defaults.
- [.claude/docs/testing.rs.md](.claude/docs/testing.rs.md) — changing tests or fixtures.
- [.claude/docs/testing-no-useless.rs.md](.claude/docs/testing-no-useless.rs.md) — deciding which regression tests are needed.
- [.claude/docs/time-api.rs.md](.claude/docs/time-api.rs.md) — changing clocks, durations or dates.

## XML (`.xml`)

- [.claude/docs/xmlstarlet.md](.claude/docs/xmlstarlet.md) — editing or validating XML.

## Linter-enforced

The linter checks these completely. Read the relevant source when diagnosing a finding or when the
applicable linter cannot cover the changed code. Reuse the runner's evidence for the reviewed revision.

- [.claude/docs/data-class-default-values.kt.md](.claude/docs/data-class-default-values.kt.md)
- [.claude/docs/imports.kt.md](.claude/docs/imports.kt.md)
- [.claude/docs/no-it.kt.md](.claude/docs/no-it.kt.md)
- [.claude/docs/serial-name.kt.md](.claude/docs/serial-name.kt.md)
- [.claude/docs/closure-naming.rs.md](.claude/docs/closure-naming.rs.md)
- [.claude/docs/imports.rs.md](.claude/docs/imports.rs.md)
